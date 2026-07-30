---
description: "Durable planning for crash-resilient autonomous work. Use before starting, deferring, or finishing any task; when deciding whether work goes in SPRINT vs BACKLOG; when writing a task entry so a fresh agent (or you after a reboot) can resume it cold; or when an AGENTS.md references this file. Core rule: write the plan into the board BEFORE you execute it."
argument-hint: "queue <slug> | defer <slug> | pick | done <slug> | check"
---

# Scrumban — durable planning, write before you do

This skill is agent-independent: it is plain markdown about a discipline, compatible
with any agent that can read it — load it from `AGENTS.md` or invoke it directly.

A machine can reboot, a context can be cleared or reset, an agent can be interrupted —
at any moment, **including mid-task, after you've done work but before you've recorded
what you were doing or what's left.** If the plan only lived in your head, that work is
orphaned: nobody (not even future-you) knows what you were doing or how to finish.

This skill's one rule: **the board, not your context, is the source of truth for
what to do next.** Write the plan into the board *before* you execute it, keep it
current as you go, and anyone — a parallel agent, or you after a reboot — can pick up
from the board cold.

The "board" is a few markdown files checked into the repo (no app, no server):

| File | Holds | Lifetime |
|---|---|---|
| `<module>/SPRINT.md` | That module's queue — per-task "what + how" + gotchas | `[~]` while in progress, `[x]` when done |
| `<module>/BACKLOG.md` | That module's can-wait work, higher-level | until promoted to its SPRINT or dropped |
| root `SPRINT.md` | **THE BOARD** — one row per task actually in flight | added before work starts, removed when released |
| root `BACKLOG.md` | Cross-module or not-yet-scoped items only | until scoped to a module |
| `specs/*.md` | The design/plan detail a task is too big to inline | durable |
| `CHANGELOG.md` | Completed work, newest first | permanent |

**Per module, not one file per repo — if the project is big enough to have modules.** A single
flat `SPRINT.md`/`BACKLOG.md`/`BUGS.md` at the root has three failure modes, all of them observed
on a real project in 2026-07 at 630 bug entries: every agent edits the same path, so the
coordination protocol has to declare those files "shared, never an overlap" and the overlap guard
stops helping; a module's own state cannot be read from inside the module; and one flat sprint
mixes *planned*, *someone is doing this right now* and *done*, so "what is happening" needs the
whole file plus a cross-check against the claim directory.

**Two levels, two different questions.** A module sprint is a QUEUE with exactly two states —
`[~]` in progress, `[x]` done. There is deliberately no "planned": not-started work belongs in
that module's backlog, and a queue with a planned state just becomes a second backlog. The root
board answers *what is in flight right now*, one row per live claim:

```markdown
| task | module | claim | state | notes |
|---|---|---|---|---|
| SLUG | v2/ | v2-front-arity | in progress | one line on where it stands |
```

The same task appears in both places on purpose, and both are written in the SAME commit as the
claim — a board row without a claim is a lie, a claim without a board row is invisible work, and
writing them together means they cannot drift by more than one commit.

**Action dispatch** — pick the section for your situation:

| Situation | Section |
|---|---|
| About to start something not yet written down | [→ queue](#queue-before-you-execute) |
| Found a follow-up / want to postpone an edge case | [→ defer](#defer-the-moment-you-decide-to) |
| Choosing what to work on next | [→ pick](#pick-from-the-board) |
| Finished a task | [→ done](#done-record-the-outcome) |
| "Could a fresh agent resume from the board right now?" | [→ check](#check-resume-cold) |

---

## queue — before you execute

**If you want to do something, queue it first, then calmly do it.** Even if you're
about to do it immediately. The 20 seconds of writing it down is the insurance.

1. Decide urgency:
   - **Do-soon** (this work session, or it blocks/unblocks something, or someone's
     waiting) → the MODULE's `SPRINT.md`, plus a row on the root board.
   - **Can-wait** (a nice-to-have, a non-blocking follow-up, a someday cleanup) →
     that module's `BACKLOG.md`.
   - When unsure, SPRINT — a visible item costs nothing; a forgotten one costs the
     work.

   **The moment you discover a new problem** — a bug, something worth fixing, building,
   or investigating — triage it *immediately* into the board, before you decide for
   certain what to do about it. Don't carry it in your head "to handle later":

   - → **the module's `SPRINT.md`** if it is **urgent, OR critical, OR easy to do, OR just needs a
     quick check** before you can decide for sure. (Even "verify whether this is real,
     then decide" is a SPRINT item — the cheap investigation is the task.)
   - → **that module's `BACKLOG.md`** if it is **not urgent AND not critical AND hard/unclear** —
     you're not even sure it should be done, but it *might* matter and is worth
     discussing later. The backlog is exactly where "maybe, let's talk about it" lives
     so it isn't lost and doesn't bloat the active sprint.

   The point: discovering it is enough to *record* it. The board decides its fate, not
   your memory.
2. Write the entry so it is **resume-cold** — a fresh agent with zero context must be
   able to do it. See [anatomy](#anatomy-of-a-resume-cold-entry).
3. If the task is non-trivial, the design/plan goes in `specs/<slug>.md` and the
   board entry points to it (keep the board scannable). Per `spec-dev`: write the
   spec *first*, commit it, then implement.
4. Commit the board/spec change on its own (don't bury planning inside a code
   commit). Now do the work.

The failure mode this prevents: you start coding from a plan in your head, get three
files deep, the context clears, and the next agent finds half-finished edits with no
note of the intent, the remaining steps, or the gotcha you'd just discovered.

## defer — the moment you decide to

Mid-task you will surface follow-ups: an edge case you're scoping out, a second bug
you noticed, a "we should also…". **Queue it the instant you decide to defer it** —
do not carry it in context "to write down later." Later is a reboot away.

- A follow-up to the current work, still soon → new item in the same module's `SPRINT.md`.
- Genuinely not now → that module's `BACKLOG.md`.
- Include the repro / pointer / the one-line "why deferred" so it's actionable later.

Honest scoping is a feature: deferring with a written entry is *better* than silently
dropping it or silently expanding scope. The board is where "not now" is recorded so
it isn't "never."

## decide — resolve it yourself, park the alternatives

Most "questions" that surface mid-task are not questions for the human. They are
choices you are competent to make and the human would answer with "use your
judgement." **Default to deciding, and record the decision. Reserve asking for the
cases where a wrong guess is unsafe or unrecoverable, or where the answer is a
preference only the owner holds** (product intent, priorities, naming they care about,
anything outward-facing or destructive).

The rule of thumb: *if you can name a defensible default and the cost of being wrong is
a revert, take the default and say so.* Stopping to ask converts minutes of work into
hours of latency, and the human is answering with less context than you have right now.

When a fork is real but the alternatives are heavy, do **not** turn it into a blocking
question and do **not** silently pick the biggest option:

1. **Take the smallest defensible option now** — the one that is independently
   shippable and easy to reverse.
2. **Write the rejected alternatives into the board** — `SPRINT.md` if it's the natural
   next slice, `BACKLOG.md` if it's genuinely not now — each with its one-line
   trade-off and what would make it the right call.
3. **State the assumption in the commit / your report**, so the owner can redirect
   cheaply if they disagree.

That way the fork is preserved as work, not as an open question in someone's inbox. An
alternative parked in `BACKLOG.md` with its trade-off costs nothing and is there the day
it becomes right; the same alternative held as "I should ask about this" is lost at the
next reboot.

**What still deserves a question:** an irreversible or outward-facing action; a decision
that would invalidate work already shipped; a genuine conflict between two stated
instructions; or a case where every option is bad and you want the owner to know before
you spend the time. Ask those *while continuing everything that doesn't depend on the
answer* — a blocking question that stops all work is the last resort, not the first.

## pick — from the board

When choosing what to do next, read the board, not your memory of it.

1. Work the module's `SPRINT.md` top-to-bottom (it's ordered by intent). An item is available only
   if it isn't already claimed/in-progress by another agent — honor the `multi-agent`
   claim protocol when parallel agents share `origin/main`.
2. Re-read the item's "how" + its spec before starting. If it's stale (already done,
   superseded), reconcile the board first ([done](#done-record-the-outcome) /
   delete), then pick the next.
3. If nothing in SPRINT is ready, promote the most valuable BACKLOG item into SPRINT
   (write the "how"), then start it. Don't start un-queued work — queue it first.

## done — record the outcome

A finished task isn't finished until the board says so.

1. Mark the SPRINT item `- [x]` and **append the outcome on the same line/block**:
   the commit/pin, the result (numbers, behavior), and any surprise. Don't delete it —
   the "what we did + why" is the next agent's context.
2. Add a `CHANGELOG.md` entry (newest first).
3. Move any follow-ups you spawned into SPRINT/BACKLOG (see [defer](#defer-the-moment-you-decide-to)).
4. Doc/board updates go in their **own commit**, separate from code (so a revert of
   one doesn't drag the other).

## check — resume-cold

Before declaring work complete, before any context reset, and periodically during long
runs, ask: **"If my context vanished right now, could a fresh agent continue purely from
the board + specs + memory, without re-deriving anything?"**

If the honest answer is "only if they re-discover X / re-run Y / re-decide Z" — write
X, Y, Z down first, then continue. The board is the contract between sessions and
between parallel agents; treat it as load-bearing.

---

## Anatomy of a resume-cold entry

A good SPRINT/BACKLOG item answers, in a few lines, everything a stranger needs:

- **What** — the outcome, in one line (`- [ ] **slug** — <one-line goal>`).
- **Why / value** — so the next agent can prioritize (and not redo rejected work).
- **How** — the approach, the files/functions to touch (`Foo.scala ~line`), the
  chosen design *and the alternative you rejected with the one-line reason*.
- **Repro / baseline** — the failing input, current numbers, the command to verify.
- **Gotchas** — the trap you hit or nearly hit, and what catches it.
- **Done-when** — the acceptance check / the gate to run.

Defense in depth: the same load-bearing fact (a baseline, a gotcha) often belongs in
*two* places — the SPRINT entry (where "what to do" is read) and the spec (self-
contained reading) — so a careless edit to one doesn't lose it. Reusable methodology
that outlives the task goes to long-term memory, not just the board.

## Relationship to the other skills

- **`spec-dev`** — for any non-trivial task: write `specs/<slug>.md` first, commit it,
  then implement. The SPRINT item points at the spec; the spec is the "how" in full.
- **`multi-agent`** — when parallel agents share `origin/main`: a SPRINT item is
  claimed before work and released/marked done after, per its claim/heartbeat
  protocol. Scrumban says *what's on the board and how to write it*; multi-agent says
  *how parallel agents coordinate around it*.
- **`bugs`** — a discovered/reported bug is *also* a board item (queue it here per the
  triage above), but it gets its own durable ledger (`BUGS.md`) and fix loop in the
  [`bugs`](../../bugs/commands/bugs.md) skill.
- **`rozum`** — **prefer rozum for coordination whenever it's available.** When a queued
  item touches another project or needs the human, raise it in the room rather than
  working in silence; the board records, the room coordinates.

The throughline across all three: **nothing important lives only in your head.** Plan
on the board, design in the spec, coordinate via claims, record outcomes in the
changelog and memory. A reboot should cost minutes, not work.
