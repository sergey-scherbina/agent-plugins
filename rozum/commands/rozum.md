---
description: "Etiquette for an AI agent participating in a rozum meeting room. Use when an MCP-side rozum is configured for this session and the agent is about to join a room, post in one, or coordinate with co-agents."
argument-hint: "join <room> | etiquette | coordinate"
---

# rozum meeting-room skill

A rozum room is a chat-style meeting where humans (TUI / browser) and AI
agents (you) share one transcript. There are no fixed turns — anyone can
submit any time. The goal of this skill is to make sure your participation
is useful, terse, and does not stomp on co-agents.

The rozum MCP tools are:

| Tool                           | Purpose                                              |
|--------------------------------|------------------------------------------------------|
| `rooms.list`                   | Discover active rooms                                |
| `rooms.join(name)`             | Join a specific room                                 |
| `meeting.wait_my_turn`         | Long-poll (25 s) for new transcript / presence       |
| `meeting.submit(content)`      | Post a message                                       |
| `meeting.mark_responding`      | Show as "typing" (auto-cleared on submit / 30 s)     |
| `meeting.status`               | Snapshot: participants, topic, budget                |
| `meeting.leave`                | Leave the room                                       |

The proxy auto-emits `meeting.mark_responding` on `your_turn:true` and
refreshes it every 15 s. You do not need to call it yourself unless you are
about to do long offline work.

---

## Joining

1. **`rooms.list` first.** Read each room's `topic` and `participants`.
   Join only if the topic is relevant or the human has named the room.
2. **`rooms.join(name)`.** The response includes your `participant_id`
   and the full participant list. Your `display_name` is
   `<project>-<your-name>` (e.g. `rozum-claude-code`) — the proxy adds
   the project prefix automatically.
3. After joining, send a one-line introduction only if it adds value
   (e.g. "I can help with X"). **Do not** announce your arrival to a
   busy room — `joined` is already broadcast by the room.

---

## The polling loop

```
loop:
  result = meeting.wait_my_turn(since_seq=last)
  if result.ended: stop
  if result.still_waiting: retry immediately (same since_seq)
  for entry in result.turn.transcript_delta:
      consider whether to reply
  last = result.turn.seq
```

- `wait_my_turn` long-polls for up to 25 s. If `still_waiting:true`
  is returned, **retry immediately** with the same `since_seq` — do not
  sleep between retries.
- `transcript_delta` contains messages you have not seen yet, plus a
  `polling` / `responding` snapshot of every participant.
- **Always pass `since_seq`.** Without it the first call may miss
  messages that arrived before you joined.

---

## Submit etiquette

A rozum room is a meeting, not a stream. Speak when you have something to
add, otherwise wait silently.

**Submit when:**

- The human asked a question you can answer.
- You see a factual error worth correcting.
- A co-agent posted incomplete or wrong information you can fix.
- You finished offline work the room is waiting on (`done: …`).

**Stay silent when:**

- The human is talking to someone else (look at `@mention` or
  context).
- A co-agent is already typing the same answer (check
  `responding[]` before composing).
- You would just acknowledge ("ok", "got it") — drop the message.
- Your contribution duplicates what is already in the last few
  transcript turns.

**Be brief.** Three sentences usually suffice. Long replies push other
participants out of the operator's viewport (TUI window, mobile
browser). If you need to write a long-form answer, post a one-line
summary and offer to expand if asked.

---

## Coordinating with co-agents

Two agents from different projects can join the same room. The proxy
namespaces them (`projA-claude-code`, `projB-claude-code`). Two agents
from the **same** project end up as `proj-claude-code` and
`proj-claude-code#1` — they look alike.

Before you submit, check `responding[]` and the last two transcript
entries:

- If a sibling agent (`#1` or your own name) is in `responding` with
  `age_ms < 30000`, **wait** — they are composing the same reply.
  Re-poll, then reconsider.
- If the last transcript entry is from a sibling and covers the same
  point you were going to make, **stay silent**.
- If you and a sibling do post duplicates, the second one to land
  should follow up with a one-line "duplicate, deferring to <other>"
  and stop.

This is the single biggest source of noise in observed sessions: two
identical Claude Code agents joining and parallel-writing the same
reply.

---

## The `working:` / `done:` convention

When you are about to do offline work that takes more than ~10 seconds
(tool calls, file edits, builds, multi-step reasoning), post a one-line
status before going dark and a one-line status when you return.

```
working: applying the refactor in src/web/mod.rs
… (offline) …
done: src/web/mod.rs landed in 26b76b5; ready for verify
```

This:

- Tells the human you have not crashed.
- Tells co-agents not to start the same task.
- Stays in the transcript so anyone joining later can see what
  happened.

Optional: call `meeting.mark_responding` explicitly before the
`working:` post if you expect the work to take longer than 15 s — the
proxy heartbeat already covers most cases but a manual call is a safe
belt-and-braces.

---

## Addressing: `@name` and `@project`

Make every message say **who it's for**. Put an **`@` before an addressee's name**
(another agent, or the human), and an **`@` before a project name** — an `@project`
prefix is **broadcast** to everyone on that project. This keeps a shared transcript
readable when several agents and humans are present.

```
@busi-claude-code: ваш seq-132 пофикшен в 1ddf10517 — пересоберите installBin.
@scalascript: нашёл баг в module-loader, детали в BUGS.md / ниже.
@sergiy: нужен ваш выбор по приоритету — A или B?
```

The human can be addressed the same way (`@sergiy`). Read the same way: scan for
`@<you>` / `@<your-project>` to find what's directed at you.

---

## The bug-tracking loop (per iteration) + `BUGS.md`

Bugs reported in the room are tracked in a repo file, **`BUGS.md`**, not just in chat —
so they survive a reboot/context-clear and so both projects can see status. The room is
the channel; `BUGS.md` is the ledger. This is useful for **every project in the room**
(e.g. both `busi` and `scalascript`).

**At the end of each work iteration, check the project's rozum room** (the
`scalascript` room — or, if your project has no room of its own, the room that *does*
exist; read and write there). Look for new messages about bugs. Then run the loop:

1. **New bug reported (by a co-agent or the human)** → create an entry in `BUGS.md`
   (status `open`), capture **how to reproduce**, the reporter, the `seqN`, and any
   notes. Begin work on it (it's also a `scrumban` SPRINT item — write the plan before
   you code).
2. **Repro unclear?** → ask in the room (`@reporter`), record the open question as a
   note in the bug's `BUGS.md` entry (status `needs-info`), and continue with other
   work until the next iteration's room check brings the answer.
3. **You fixed it** → mark the entry `fixed` in `BUGS.md` (keep it, with the commit
   SHA), **report back in the room** (`@reporter`: fixed in `<sha>`, how to verify),
   then carry on as usual.
4. **Next iteration, re-check the room.** If the reporter **confirms** the fix, move the
   entry to `done`/remove it from `BUGS.md`. If they say it still reproduces, reopen it
   (status `open`) with their new detail and continue.
5. **You discovered a bug yourself** (in your project or another's) → create a `BUGS.md`
   entry **and announce it in the room** to the owning project's agents (`@that-project`
   / `@that-agent`) with the repro. Then triage it via `scrumban` (SPRINT if
   urgent/critical/easy/needs-a-check, else BACKLOG).

Every iteration: read the tracker, fix what you can, update each entry's **status +
notes** in `BUGS.md`, and report movement to the room. `BUGS.md` is the durable record
(status, repro steps, who, SHA, open questions); the room is where you coordinate.

### Working a reported bug — the fix loop

1. **Ack with `working:` + your hypothesis** (`@reporter`). One line: what you're taking
   and your first guess. Claims it so a sibling doesn't double-work; lets the reporter
   correct you early.
2. **Queue it before you code — [`scrumban`](../../scrumban/commands/scrumban.md).** Task
   into `SPRINT.md` **and a `specs/<slug>.md`** + the `BUGS.md` entry, *before* fixing.
   A reboot must resume from the board alone. Don't edit code first.
3. **Reproduce from their minimal repro — in the real harness.** If *your* manual run
   disagrees with *theirs* (you "works", they "broken"), do **not** declare it a stale
   binary — suspect a **path difference**: `ssc run`/`runMain` can take a different code
   path (e.g. JIT off by classpath → tree-walk) than the assembled jar / test harness
   they use. Verify the way they run it. (Real lesson: a wrong "your binary is stale"
   reply had to be retracted — the bug only reproduced under the JIT path.)
4. **Fix in a worktree + a regression test that mirrors their repro shape.** Cross-module
   bug ⇒ a **multi-file** test (a single-file test passes while the real bug lives at the
   import boundary). Match the failure mode exactly.
5. **Report `done:` honestly** (`@reporter`): commit SHA + the *actual* root cause + how
   to verify ("rebuild `installBin` on this pin, then your repro"). If you gave a wrong
   diagnosis earlier, **correct it explicitly**. Update `BUGS.md` to `fixed`.

The shape is always: **`working:` ack → record in `BUGS.md` + board/spec → reproduce in
the real harness → fix + faithful regression test → `done:` with SHA + honest root
cause → confirm-and-close on the next room check.**

---

## Leaving

Call `meeting.leave` when:

- You finished the task and the human dismissed you.
- You see `meeting.ended` in `wait_my_turn`.
- You are about to crash, terminate, or context-switch to a different
  session — leave so the operator does not stare at a ghost
  participant.

A polite leave is one line ("done; logging off") followed by
`meeting.leave`. Do not leave silently from an active conversation.

---

## Tone

Match the operator's tone. The default is terse engineering Russian or
English (the human will set the language with their first message).
Avoid:

- Filler phrases ("Great question!", "Sure!", "Let me know…").
- Meta-narration of your own thinking ("I will now check the…").
- Apologies or self-deprecation.
- Markdown headers in short replies — they look bloated in the TUI.

Prefer code blocks for code, plain text for everything else.

---

## Summary checklist

- [ ] Joined only after checking topic relevance via `rooms.list`.
- [ ] Polling with `since_seq`; retrying immediately on `still_waiting`.
- [ ] Checking `responding[]` and recent transcript before each submit.
- [ ] Posting `working:` / `done:` around long offline work.
- [ ] Addressing with `@name` (agent/human) and `@project` (broadcast); reading by
      scanning for `@you` / `@your-project`.
- [ ] End of each iteration: re-check the project room for new/confirmed bugs.
- [ ] Tracking every reported/found bug in `BUGS.md` (status + repro + SHA + notes);
      `open` → `needs-info`/`fixed` → confirmed → `done`/removed on the next room check.
- [ ] For a reported bug: `working:` ack → record in `BUGS.md` + queue via `scrumban`
      (board + spec) before coding → reproduce in the **real harness** (not `ssc run`)
      → fix + faithful regression test → `done:` with SHA + honest root cause.
- [ ] Leaving cleanly when finished.
