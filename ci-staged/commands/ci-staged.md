---
description: "CI shape for a repo where several agents commit to one main/master and share ONE build box: a pre-merge gate scoped to a lane's own changed modules (then their dependents, in that order — never the whole family), and a single serial post-merge runner that gates the WHOLE build once per batch of landings and is the only process that pushes, bisecting and reverting the culprit on red. Use when N agents landing at once are collapsing the shared box (each running a full/closure-sized gate, each re-gating for every sibling's unrelated change), when wiring a lane's pre-merge gate or a post-merge runner, or when an AGENTS.md points here for why the gate is shaped this way."
argument-hint: "init | check | cite <rule>"
---

# ci-staged — your modules first, then their dependents; the whole build once, before the push

This skill is agent-independent: plain markdown about a CI shape, not a build tool. It has
two halves, in the `policy` skill's own style.

**Part A** is the shape itself, in generic form — what any repo with several agents landing
to one branch on one shared box needs, independent of the build tool (sbt, Bazel, npm,
cargo — anything with a dependency graph and a test task).

**Part B** is how a concrete project *instantiates* it: the handful of things Part A
deliberately leaves open (how "affected" is computed, the gate script's name, the lock's
shape, what a "module" even is), plus a worked example from a real sbt monorepo
(`okay`'s `specs/ci-staged.md`, `project/Affected.scala`, `scripts/ci-runner.sh`).

The shape exists because of one measured failure, not a hypothetical one: **N agents each
running a full-family gate before merging collapses a shared box.** Every lane's pre-merge
gate closes its diff over its dependents and runs the closure NOW, in a worktree of its
own, at the same time as every other lane doing the same — most of it re-checking what a
sibling's disjoint change already proved minutes ago. A push-immediately rule compounds it:
`land.sh` (or its equivalent) refuses to land over ANY sibling source commit, so a disjoint
one-line change sends every other lane back to a fresh full gate. The RAM guard kills the
heaviest JVM, the kill is a retry, the retry is another full gate — a positive feedback loop
with no external cause, on a box that was otherwise idle five minutes earlier.

---

## Part A — the shape, generic

### A-1 · Two gates, not one, and they check different things

- **The PRE-MERGE gate is scoped to the lane.** It runs the lane's own changed modules'
  tests FIRST, then a second stage over the modules that depend on them — TWO ordered runs,
  not one unordered closure, so a lane that broke its own module learns that before paying
  for anything downstream. The set is exactly what a full "affected" closure has always run;
  the win is the order (fail fast on your own work) and the narrower RE-GATE trigger below —
  not a smaller set. (A team may choose to compile-only, not test, the dependent stage — see
  A-6 — but ordering the two is not optional: it is what buys the fail-fast property.)
- **The POST-MERGE gate is scoped to the WHOLE BUILD, and runs exactly ONCE per batch of
  landings**, in a single serial process, before that batch reaches the branch's public
  remote. This is where a cross-module interaction that neither lane's own gate could see —
  lane X changes a dependency's BEHAVIOUR under an unchanged signature, lane Y lands beside
  it in a module X never touched — is actually caught, and it is caught once, not once per
  lane that happened to be landing that hour.
- **Nothing else runs the whole build.** A lane's own gate never re-proves what the shared
  runner will prove for it anyway; that duplication is the box collapsing.

### A-2 · The re-gate trigger narrows to your own modules

A lane's obligation to re-run its pre-merge gate before landing is triggered only by a
sibling's SOURCE change that intersects the lane's OWN changed modules, or the build
definition itself (a build-file change is, correctly, everyone's problem). A sibling's
disjoint landing is rebased onto and landed WITHOUT a re-gate — the two together are the
post-merge runner's problem, once, not each lane's problem, N times.

This is the single highest-leverage rule in this skill. Before it, "master gained a source
commit" was answered with "re-gate the family"; after it, the question becomes "does that
commit's diff touch a module I also touched," which is usually no.

### A-3 · One serial runner, one lock, and it is the only pusher

- A **mutex** (a lock directory made with an atomic `mkdir`, a PID file inside it, staleness
  checked by whether that PID is alive) ensures exactly one whole-build gate runs at a time.
  A held lock with a dead PID is stale and is taken over, logged as such.
- The runner reads the range **since the last push** (`origin/main..main`, or your VCS's
  equivalent) — not a state file of its own. What was PUSHED is what was green; a second
  "last known good" record is a second copy of a fact git already keeps, and the two could
  disagree.
- A range whose diff is **bookkeeping-only** (boards, claims, changelogs, docs — whatever
  your project routes through P-3 of the `policy` skill) is pushed AT ONCE, no gate: nothing
  in it could fail a test.
- Otherwise the runner gates the WHOLE build and pushes only on green. A push that is
  REJECTED (a remote moved concurrently — an edit made directly on the remote, or a race
  with another writer) is re-read and retried the SAME turn, never forced.
- **No lane pushes directly.** Landing ends at the merge; a KICK to the runner (wake a
  loop already running, or start one detached) replaces the push. The kicking call returns
  at once — a landing does not block on the whole-build gate.

### A-4 · Red is a revert, not a hunt

- A red whole-build run is BISECTED over the landings since the last push, using the SCOPED
  pre-merge gate at each candidate (A-1) — not the whole build again at every step. A bisect
  over five disjoint landings then costs five scoped gates, not five whole builds.
- Exactly one landing commit in the range needs no bisect: it is the culprit.
- The first bad commit is REVERTED by the runner — a record naming the culprit, its author's
  lane and the failing run is written alongside the revert (your P-3 board's own shape) —
  and the NEXT turn gates and pushes the range WITH the revert already in it. The remote
  never carries the fault at all, because the push happens only after a green whole-build
  gate, and the revert is part of what made this one green.
- The bisect runs in a WORKTREE (or clone) of its own, never the shared checkout everybody
  merges into. The main checkout's branch pointer never moves for it.
- **The runner never widens an assertion and never retries a genuine red.** A run that
  reached a verdict has said something true about the tree; a loop that re-rolls a red is a
  machine for landing broken trees (P-6 of `policy`: "a gate must be observed failing before
  it is trusted" applies here too — a red the runner ignores is a gate that cannot see).

### A-5 · Why the author still learns, just one merge later

A lane loses the guarantee that a cross-module interaction fails IN ITS OWN pre-merge gate.
It gains: no lane pays for closures it did not need to test synchronously, no lane's landing
blocks on the whole build, and the box stops collapsing. The trade is explicit — say it out
loud when adopting this shape, because the instinct on the first red whole-build run is to
ask "why didn't MY gate catch this," and the answer is "by design; that is what stage two is
for."

### A-6 · What Part A deliberately leaves open

- Whether the pre-merge dependent stage TESTS or only COMPILES the dependents. Testing
  (A-1's default) catches a behaviour change under an unchanged signature closer to the
  source; compiling only catches a broken signature and defers behaviour checks entirely to
  the post-merge runner. Pick one and say why in your Part B — do not leave it ambiguous,
  because it changes what "my pre-merge gate passed" is allowed to mean to a lane's author.
- What counts as a "module" for the re-gate trigger (A-2) — a top-level directory, a build
  target, a package. Whatever it is, it must be the SAME boundary the dependency-graph tool
  uses (A-2's guard and A-1's scoping must share one vocabulary — the same P-6 rule from
  `policy` about duplicated logic needing one vocabulary on both sides).
- How long the runner waits for a quiet box before running anyway, and what "quiet" means on
  your hardware. This skill only says the runner is serial and locked; the retry/backoff
  policy around a shared box's own load is a separate, hardware-specific concern (see your
  project's own gate-retry tooling, if any).

---

## Part B — instantiating it in a project

### B-1 · The slots to fill

| Slot | What it is | `okay`'s instantiation |
|---|---|---|
| **dependency graph** | how "what does this diff touch, and what depends on it" is computed | `project/Affected.scala`, an sbt `AutoPlugin` reading `unmanagedSourceDirectories` per project and closing over `dependencies` |
| **pre-merge command** | the scoped, two-stage gate a lane runs before merging | `scripts/gate.sh "affected <ref> test <platform> staged"` |
| **module boundary** | the unit A-2's re-gate trigger checks | first path component (`okay-lex/…`); `project/` and the root build file count as "the build," everyone's problem |
| **dependent stage: test or compile** | A-6's open choice, decided | TEST (not compile-only) — the operator's explicit choice; see `specs/ci-staged.md`'s Decisions for the rejected alternative and why |
| **gate wrapper** | retry/quiet-wait/stall-watchdog around the raw test command | `scripts/gate.sh` + `scripts/gate-retry.sh` (extended with an optional `[cmd]` argument so the runner reuses it) |
| **the lock** | A-3's mutex | a `mkdir`'d directory under `.work/ci/` (gitignored), holding the runner's PID |
| **the range** | what the runner gates each turn | `origin/master..master` — no separate "last green" file; what is pushed IS what was green |
| **bookkeeping paths** | what makes a range push-without-gating (A-3) | `.work`, `sprint.d`, `backlog.d`, `changelog.d`, `docs`, `specs` |
| **runner script** | A-3/A-4's implementation | `scripts/ci-runner.sh once\|loop\|kick\|status\|--read` |
| **bisect gate** | the scoped command A-4's bisect uses per candidate | `scripts/gate.sh "affected <from>..HEAD"` (closed scope; `staged`'s ordering buys nothing inside a bisect step) |
| **revert record** | where A-4's culprit record goes | `changelog.d/ci-revert-<slug>.md`, folded into the revert commit |
| **land hook** | where a lane's landing script stops pushing and starts kicking | `scripts/land.sh` step 8: `sh scripts/ci-runner.sh kick` |

### B-2 · The order to build it in

1. **The dependency-graph query**, with a `--plan`/dry-run mode that prints what it would run
   without running it — this is what makes the shape's own selftest possible without paying
   for a real build per case (see B-4).
2. **The pre-merge two-stage command** (A-1) on top of it, and the module-boundary check
   (A-2) as a small, pure function shared by the graph query and the land script — test it
   on a MODULE-level path, not only a root-level one; that is where an off-by-one in "what is
   a module" hides.
3. **The lock and the range** (A-3), with `once` as a single idempotent function: nothing to
   do → exit clean; bookkeeping-only → push; otherwise → gate.
4. **The bisect and revert** (A-4), in a throwaway worktree, LAST — it is the piece with the
   most moving parts and the one a selftest most needs (B-4).
5. **The land-script hook** (B-1's last row), only once 1–4 are gated and merged themselves —
   bootstrapping problem: the script that stops pushing directly needs the runner to already
   exist on the checkout that runs it.

### B-3 · Instantiation checklist

```
[ ] the dependency graph has a --plan/dry-run mode with no side effects
[ ] the pre-merge gate is TWO ordered stages, not one closure (verify: a red in stage 1
    never starts stage 2 — check the exit code path, not just the log text)
[ ] the module boundary is ONE function, used by both the graph query and the re-gate check
[ ] A-6's test-or-compile choice for the dependent stage is written down, not implicit
[ ] the runner's lock is taken with an atomic primitive (mkdir/O_EXCL, not a lockfile
    written non-atomically) and a stale holder (dead PID) is detected and taken over
[ ] the runner is the ONLY thing that pushes; grep the landing script for any other
    `push` and remove it
[ ] a bookkeeping-only range pushes without invoking the gate at all
[ ] the bisect runs in a worktree/clone that is never the shared checkout
[ ] a revert is followed by a green whole-build push BEFORE anything else lands on top —
    i.e. the runner's next turn, not a human's separate action
[ ] a selftest exists against a FIXTURE (a throwaway repo + bare remote + a fake gate that
    answers what the test controls), never the real repo and never the real build tool
```

### B-4 · What the selftest can and cannot prove

It can prove, cheaply and deterministically, against a fixture: nothing-to-do is a no-op;
a bookkeeping range skips the gate; green pushes exactly the gated commit; red pushes
nothing; a remote genuinely ahead is merged (never rebased) before gating; the lock refuses
a second runner and is taken from a dead one; a red range with one landing reverts without a
bisect; a red range with several landings reverts exactly the one a REAL bisect (over a
marker file the fake gate keys on, not an env var) finds; the shared checkout's branch
pointer never leaves the trunk during a bisect.

It cannot prove your real build's dependency graph is correct, or that the real gate
tool's retry/stall logic behaves under real load — those need the real tool, on the real
repo, which is why B-2 puts the fixture-testable pieces (1–4) before the one that needs the
real thing wired in (5).

**A pathspec built from a shell variable is a known trap here**, worth stating because it
cost a real hour finding: word-splitting a variable's value does not strip the QUOTE
characters the value contains — quoting only means something while the shell PARSES script
text, not when it expands an already-computed string. Filtering a file LIST in the shell
(a loop or `grep -v` over newline-separated paths) has no such trap; building a pathspec
argument from an interpolated variable does. If your bookkeeping-only check (A-3) is built
this way and passes anyway, it is passing by accident — a selftest with a bookkeeping-only
case (B-3's second-to-last line) is what catches it, and it caught it in `okay`'s own build.

### B-5 · Adopting into a repo that already pushes per-lane

Do not add the runner beside the existing push — that runs the whole build twice (once per
lane, once by the runner) until someone remembers to remove the old one. Cut over in one
lane: land the runner (B-2 steps 1–4), THEN in the SAME lane flip the land-script hook
(B-2 step 5) so the old direct push is gone the moment the new path exists. A transition
period with both is exactly the duplicated-apparatus failure `policy`'s P-6 warns about,
just applied to CI instead of a board.
