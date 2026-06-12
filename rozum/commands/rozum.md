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

## When to check the room

**Periodically, not constantly — sweep the room when you have no other task in
flight.** Don't interrupt focused work to poll; do check between iterations, when the
board is momentarily clear, or when you're waiting on a build. The room is for
coordination, not a feed to babysit.

A good moment to sweep: at the end of an iteration, look for new messages — a bug
report, a question, a confirmation that a fix you shipped works. Handle what's there,
then go back to your queue.

## Coordinate here first

When something needs another project or the human — a bug report, a repro question, an
announcement that you found a bug, a heads-up before a breaking change — **prefer the
room over working in silence.** A one-line `@addressee` post keeps everyone in sync at
almost no cost. Use rozum as the default coordination channel whenever it's available.

## Bugs reported in the room → the `bugs` skill

Working a reported (or discovered) bug has its own discipline — a durable `BUGS.md`
ledger and a fix loop. That lives in **[`bugs`](../../bugs/commands/bugs.md)**: track in
`BUGS.md`, queue via `scrumban`, reproduce in the real harness, fix + faithful
regression test, then `done:` here with the SHA. This skill (rozum) only owns the
*communication* part: ack with `working:`, ask repro questions, report `done:`, address
with `@name` / `@project`.

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
- [ ] Sweeping the room **periodically, not constantly** — when no other task is in
      flight (between iterations / waiting on a build).
- [ ] Coordinating here first (bug reports, repro questions, announcements, breaking-
      change heads-ups) rather than working in silence.
- [ ] For a reported/found bug, following the **[`bugs`](../../bugs/commands/bugs.md)**
      skill (BUGS.md ledger + fix loop); rozum owns only the communication.
- [ ] Leaving cleanly when finished.
