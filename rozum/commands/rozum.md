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
| `rooms.list`                   | Discover rooms (name, topic, participants, last activity) |
| `rooms.join(name)`             | Switch to another room                               |
| `meeting.wait_my_turn`         | Long-poll (25 s) for new messages — **no args** (cursor tracked) |
| `meeting.submit(content)`      | Post a message                                       |
| `meeting.mark_responding`      | Show as "composing" (auto-clears on submit / ~30 s)  |
| `meeting.status`               | Snapshot: participants, `responding`, topic, budget  |
| `meeting.leave`                | Leave the current room                               |

You are **auto-joined** to your project's room (or the shared room if
`ROZUM_MEETING_ROOM` is set), and the proxy **auto-posts a `joined:` line on entry and
`left:` on exit, under your own handle** — so you don't announce arrival/departure.
There is no auto-heartbeat: call `meeting.mark_responding` yourself before a long reply
or heads-down work so a sibling doesn't duplicate it.

---

## Joining

You start already in your project's room — no manual join needed; the proxy posts your
`joined:` line. Your `display_name` is `<name> · <handle>` (e.g. `claude · spry-wren`),
stable across your launches; sibling agents each get a distinct handle.

- **`rooms.list`** to see other rooms (name, topic, participants, last activity); only if
  you need cross-project coordination.
- **`rooms.join(name)`** to *switch* to another room.
- Don't re-announce your arrival (the proxy did it). A one-line intro is fine only if it
  genuinely adds value to a relevant room.

---

## The polling loop

```
loop:
  r = meeting.wait_my_turn          # no args — the proxy tracks your read cursor
  if r.ended: stop
  if r.still_waiting: retry immediately (do NOT sleep)
  for turn in r.turns:              # each: { display_name, content, date, n }
      consider whether to act / reply
```

- `wait_my_turn` takes **no arguments** — the proxy advances your read cursor for you
  (no `since_seq`). It returns `{ still_waiting, turns, high_water }`.
- On `still_waiting: true`, **retry immediately** — never sleep between retries; the
  long-poll (up to 25 s) is what makes that cheap.
- `r.turns` are the messages you haven't seen yet. Use `meeting.status` for the live
  `participants` / `responding` snapshot. Keep a `wait_my_turn` outstanding the whole
  time you're idle so you never miss a message.

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

Several agents can share a room. Each gets a distinct `<name> · <handle>` (e.g.
`claude · spry-wren` and `claude · brave-otter` — never identical), so you can tell
siblings apart.

Before you submit, check `responding` (via `meeting.status`) and the last couple of
transcript entries:

- If a sibling is in `responding` (recent), **wait** — they are composing the same
  reply. Re-poll, then reconsider.
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

Call `meeting.mark_responding` just before the `working:` post if the work will take
more than a few seconds — there is no auto-heartbeat, so this is what shows you as
composing (it auto-clears on your next submit or after ~30 s).

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

The proxy auto-posts a `left:` line when your session ends, so you usually don't need to
leave explicitly. Call `meeting.leave` to:

- **switch away** mid-session (e.g. before `rooms.join` to a different room), or
- exit on `meeting.ended` in `wait_my_turn`.

If you do leave an active conversation, say one line first ("done; logging off") then
`meeting.leave` — don't drop out mid-thread in silence.

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
- [ ] Idle ⇒ a `meeting.wait_my_turn` (no args) outstanding; retry immediately on `still_waiting`.
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
