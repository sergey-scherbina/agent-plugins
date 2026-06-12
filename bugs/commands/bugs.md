---
description: "How to handle bugs durably: track every reported/found bug in BUGS.md (status + repro + SHA + notes), work the fix loop, and coordinate via rozum. Use when a bug is reported (in a rozum room or by a human), when you discover a bug, when deciding how to record/triage it, or when an AGENTS.md references this file."
argument-hint: "track <slug> | reproduce <slug> | fix <slug> | confirm <slug>"
---

# Bugs — a durable ledger and a fix loop

This skill is agent-independent: plain markdown about a discipline, usable by any agent
that can read it — load it from `AGENTS.md` or invoke it directly.

Bugs must not live only in chat or only in your head. A reported bug, a bug you found,
a half-understood symptom — all of it goes into a repo file, **`BUGS.md`**, so it
survives a reboot / context-clear and so every collaborator can see its status. The
ledger is the source of truth; a meeting room (rozum) is how you *coordinate* around it.

**Prefer [`rozum`](../../rozum/commands/rozum.md) for coordination** whenever it's
available: ack a report there, ask repro questions there, announce a bug you found
there, report the fix there. `BUGS.md` records; rozum coordinates. (Everything below
that says "in the room" assumes the project's rozum room — see the rozum skill for
addressing and etiquette.)

This composes with the other skills:
- **[`scrumban`](../../scrumban/commands/scrumban.md)** — a tracked bug is also a board
  item: write the plan into `SPRINT.md` (+ a `specs/<slug>.md` if non-trivial) **before**
  you code. Triage: SPRINT if urgent/critical/easy/needs-a-check; BACKLOG if
  not-urgent + not-critical + hard/unclear-but-maybe.
- **[`rozum`](../../rozum/commands/rozum.md)** — the coordination channel + the
  `working:`/`done:` and `@name`/`@project` conventions.
- **[`multi-agent`](../../multi-agent/commands/multi-agent.md)** — when parallel agents
  share `origin/main`, claim before working a fix.

---

## `BUGS.md` — the ledger

One entry per bug, newest first. Track at least: **status, the reporter (and `seqN` if
from a room), how to reproduce, the root cause once known, the fix commit SHA, and any
open questions / notes.** Status flow:

```
open  →  needs-info  →  fixed  →  (reporter confirms)  →  done
```

| Status | Meaning |
|---|---|
| `open` | reproduced / accepted; work to do |
| `needs-info` | blocked on a repro question asked in the room |
| `fixed` | landed on `origin/main`; reporter not yet re-confirmed |
| `done` | reporter confirmed fixed (safe to trim) |

Keep `fixed`/`done` entries with their SHA until the reporter confirms; then they can be
trimmed. `BUGS.md` is the durable record; update each entry's status + notes as it moves.

---

## The loop (run it each iteration)

**Check the project's rozum room periodically — not constantly: when you have no other
task in flight** (between iterations, when the board is momentarily clear). Don't
interrupt focused work to poll; do sweep the room when you come up for air. Then:

1. **A bug is reported** (co-agent or human) → create a `BUGS.md` entry (`open`), capture
   the repro / reporter / `seqN` / notes, ack in the room (`@reporter` + `working:` +
   your hypothesis), and queue it via `scrumban` before coding.
2. **Repro unclear?** → ask in the room (`@reporter`), set the entry `needs-info` with the
   open question, and move on to other work until the next room sweep brings the answer.
3. **You fixed it** → set the entry `fixed` (with the commit SHA), **report in the room**
   (`@reporter`: fixed in `<sha>`, how to verify), then carry on.
4. **Next sweep, re-check the room.** Reporter **confirms** → `done` / trim. Reporter says
   it still reproduces → back to `open` with their new detail.
5. **You discovered a bug yourself** (yours or another project's) → create a `BUGS.md`
   entry **and announce it in the room** to the owning project's agents (`@that-project` /
   `@that-agent`) with the repro, then triage via `scrumban`.

Every iteration: read the ledger, fix what you can, update status + notes, report
movement in the room. Useful for **every project sharing the room** (e.g. both `busi`
and `scalascript`).

---

## The fix loop (working a single bug)

1. **Ack with `working:` + your hypothesis** (`@reporter`) — claims it so a sibling
   doesn't double-work; lets the reporter correct you early.
2. **Record before you code** — the `BUGS.md` entry **and** the `scrumban` board/spec,
   *before* editing. A reboot must resume from the repo alone.
3. **Reproduce from their minimal repro — in the real harness.** If *your* run disagrees
   with *theirs* (you "works", they "broken"), do **not** declare it a stale binary —
   suspect a **path difference**: a dev runner can take a different code path (e.g. a JIT
   disabled by classpath → fall back to an interpreter) than the assembled artifact / test
   harness the reporter uses. Verify the way they run it. (Real lesson: a wrong "your
   binary is stale" reply had to be retracted — the bug only reproduced under the JIT
   path the test harness exercises.)
4. **Fix + a regression test that mirrors their repro shape.** Cross-module bug ⇒ a
   **multi-file** test (a single-file test passes while the real bug lives at the import
   boundary). Match the failure mode exactly.
5. **Report `done:` honestly** (`@reporter`): commit SHA + the *actual* root cause + how
   to verify (e.g. "rebuild on this pin, then your repro"). If you gave a wrong diagnosis
   earlier, **correct it explicitly** — the reporter is building on your words. Update
   `BUGS.md` to `fixed`; close to `done` when they confirm.

The shape is always: **`working:` ack → record in `BUGS.md` + board/spec → reproduce in
the real harness → fix + faithful regression test → `done:` with SHA + honest root
cause → confirm-and-close on the next room sweep.**

---

## Summary checklist

- [ ] Every reported/found bug has a `BUGS.md` entry (status + repro + reporter + SHA +
      notes).
- [ ] Plan written to the `scrumban` board (+ spec) before any code.
- [ ] Coordinated via `rozum` where available — ack, repro questions, announcements,
      fix reports.
- [ ] Reproduced in the **real harness**, not a dev-only runner.
- [ ] Regression test mirrors the reporter's repro shape (multi-file for cross-module).
- [ ] Status moved `open → needs-info → fixed → done`; closed only on reporter
      confirmation; room swept for new/confirmed bugs when no other task is in flight.
