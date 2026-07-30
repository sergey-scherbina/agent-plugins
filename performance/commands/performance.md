---
description: "Performance work: how to measure so the number means something, how to keep a history of benchmark runs and read its dynamics, how to find the next problem area from the results, and how to track perf tasks. Use before optimising anything, after landing any change that could affect speed, when a benchmark number surprises you, or when deciding what to optimise next. Core rule: one measurement is a hypothesis, not a result."
argument-hint: "measure <change> | record <run> | analyse | pick-next"
---

# Performance — measure, record, read the dynamics

This skill is agent-independent: plain markdown about a discipline.

Optimising is easy to *do* and hard to *know*. Nearly every wasted hour in perf work comes
from one of three places, and this skill is organised around them:

1. **The number lied** — measured once, on a busy machine, or against a stale table.
2. **The prize was assumed** — a fat frame in a profile was treated as a size of prize.
3. **The work was redone** — a plausible idea was tried, refuted, forgotten, tried again.

---

## 1 · Measuring so the number means something

### 1.1 One measurement is a hypothesis

On a machine with other work on it, an A/B of **identical code** has been measured swinging
**2.5×** on the same workload (0.263 / 0.211 / 0.429 / 0.171 s at load 5.5). If you run
before once and after once, you are sampling that noise and calling it a result.

**The alternating protocol — use this, not a before-block and an after-block:**

```
for round in 1 2 3:
    install BEFORE artifact ; run the workloads ; record
    install AFTER  artifact ; run the workloads ; record
compare the MEDIAN of the three before-runs against the median of the three afters
```

Alternating matters more than the count. Three befores then three afters puts a machine
state change (thermal, another job starting, a cache warming) entirely inside one arm.

**Swap only the artifact under test.** Rebuilding both arms between rounds reintroduces
everything you were trying to hold constant.

**Normalising against an unchanged control column is NOT sufficient.** The control's own
JIT and cache behaviour swing on the same rows for the same reasons.

### 1.2 Never compare a fresh number against a stale table

The most convincing wrong result comes from measuring today and subtracting yesterday's
table. A whole machine gets quieter or busier and every row moves together.

Real instance: a change was reported as improving a workload **271× → 115×**. Measured
against a same-session baseline it was **269×** — unchanged. Both columns had simply
dropped because the host was quiet.

**If you did not measure both arms in the same session, you do not have a comparison.**

### 1.3 State the expected size BEFORE you start

Write down what you expect to gain and from what evidence. Then the result can disagree
with you. Without it, any outcome gets narrated as a success, and a 4% change gets shipped
as a win.

### 1.4 Reproduce a "cannot run" claim OUTSIDE the harness

A workload reporting "unsupported" or "n/a" is a claim about your harness at least as often
as about your code. Run the thing by hand before it becomes a category. Three workloads
once sat in "the runtime cannot do this at all" for two days; the defect was a literal in
the benchmark wrapper.

### 1.5 How to run benchmarks, generally

Applies to any project, in rough priority order:

- **One entry point.** `scripts/bench <command> [pattern]` or equivalent. Ad-hoc
  invocations produce numbers nobody can reproduce or compare.
- **A microbenchmark harness that controls warmup and forks** on a JIT'd runtime (JMH for
  the JVM, criterion for Rust, and so on). Defaults around 3 warmup × 5 measure × 1 fork
  are a reasonable cost/precision trade; state them with the numbers.
- **A workload corpus, not one program.** A single benchmark optimises itself. A corpus of
  many small programs, each dominated by one operation kind — arithmetic loop, collection
  fold, string concat, pattern match, allocation — is what makes a RATIO TABLE possible,
  and the ratio table is what tells you where to look next.
- **A reference implementation to divide by.** Absolute times are unreadable across
  machines; `mine ÷ reference` per workload is comparable across sessions and hosts.
- **Report failures unconditionally.** A lane that swallows its exception and prints `n/a`
  is indistinguishable from a lane that legitimately cannot run the case.

### 1.6 Profile to find WHERE, never to size the prize

**Twice on one project a fat profile frame did not pay out by its weight**: a frame at 28%
of samples bought 20%; another at 25% bought nothing measurable. Failed type tests and
predictable branches are near-free once JIT-compiled — samples mark where the *thread* is,
not where the *cost* is.

**A hot frame is a place to look. It is never a size of prize.** The prize is what the
alternating A/B says after you change it.

---

## 2 · The history of runs

A single run answers "is it faster now". A history answers "what has actually been getting
better, what regressed quietly, and what have we never moved" — which is the question that
picks your next task.

### 2.1 Keep it append-only and machine-readable

One row per (run, workload). TSV or CSV, committed to the repo next to the benchmarks:

```
date         sha        host_load  workload         mine     ref      ratio  note
2026-07-29   197ae13ab  1.8        float-fold       3.150    0.0100   315    quiet host
2026-07-29   197ae13ab  1.8        arith-loop       0.0240   0.0100   2.4    quiet host
```

Non-negotiable columns and why:

- **`sha`** — a number without a commit is not evidence.
- **`host_load`** — the single most common cause of a row moving. Without it, every
  cross-session comparison is guesswork. Record it, do not wait for a quiet machine.
- **`ratio`** against a reference — the only column comparable across hosts.
- **`note`** — the one place to write "measured under a sibling build", which is what makes
  a future reader distrust the right row.

**Append, never rewrite.** A history you correct in place cannot show you a regression that
was later fixed, and that pattern is a bug signature.

### 2.2 Record a run after every change that could affect speed

Including changes you believe are neutral, and especially changes that are not about
performance at all. The regressions that survive longest are the ones nobody was measuring
for. A record costs one command.

### 2.3 Keep refuted attempts in the same place as the tasks

Every optimisation that was implemented, measured and reverted gets a line saying **what
was tried, what was measured, and why it was dropped**. Without it, the idea gets retried —
plausible-but-wrong ideas all look obviously right, which is why they were tried once.

Worked example of the distinction, worth copying: *revert a no-gain change when carrying it
costs future attention (a guard someone must maintain, an invariant someone can violate);
keep it when it costs none.*

---

## 3 · Reading the dynamics

### 3.1 The ratio table is the map

Sort by `ratio` descending and read the shape rather than the top row:

- **A handful of rows an order of magnitude worse than the rest** → an unimplemented tier,
  a wrong data representation, or a fallback path being taken. These are the cheap wins:
  the cause is structural and usually nameable in one sentence.
- **A twin pair that disagree** — the same operation on two types, one fast, one slow
  (`arith-loop` 2.4× vs `float-loop` 54×) — is the single most informative pattern in the
  table. It says a specialisation exists for one and not the other, which is a *located*
  bug, not a research project. **Look for twins deliberately.**
- **A broad plateau, everything 5–10×** → architectural: per-node dispatch, boxing, an
  interpretation layer. Price it as a programme, not a slice.
- **A row at ~1.0×** → you have parity somewhere; find out why *that* path is different.
  It is the best evidence you have about what the good shape looks like.

### 3.2 Read across runs, not only down one

- **A row that moved without a related change** — the machine was busier, or something
  unrelated regressed. Check `host_load` first; if it did not move, you have a silent
  regression and its window is the commits between the two runs.
- **A row that never moves** across many runs while its neighbours improve is either
  genuinely inherent (it is spending its time inside a dependency you do not control) or
  nobody has looked. Both are worth knowing; they lead to different actions.
- **Contention COMPRESSES ratios.** A workload that reads 2.8× on a loaded host can read
  5.1× on a quiet one — i.e. *worse*, not better. Never treat a busy-host table as a
  baseline for a quiet-host measurement, in either direction.

### 3.3 Turning a reading into a task

For each row you intend to act on, write down before starting: the ratio and its twin (if
any), the profile's top frames, **the expected size of the win and why**, and the
disqualifying evidence — what result would tell you the theory is wrong.

If you cannot name the disqualifying evidence, you are not ready to start.

---

## 4 · Tracking perf tasks

Follow the project's policy (see the `policy` skill); perf needs no separate system, only
three things done consistently.

1. **Perf items are entries with `kind: perf`**, on the board of the module where the fix
   goes — not in a separate performance file. A second axis in the filesystem gives an
   entry two plausible homes.
2. **A per-type document is a GENERATED index plus hand-written analysis.** The index comes
   from the same headers everything else is queried by, so it cannot drift. The analysis —
   why a ratio is what it is, what was refuted, how to measure — is the valuable half and
   no schema will hold it. Generate the first, hand-write the second, and gate the
   generated part.
3. **Watch what the query cannot see.** If planned work lives in a file with no header
   schema, a perf query returns only the defects and *looks complete*. Either give those
   entries headers or make the tool print what it did not read. (Measured on one project:
   `--kind perf` answered 3 of 12 known items, silently.)

**A perf entry is done when the number moved**, verified with §1.1, recorded in the history
with §2.1, and stated in the commit with both medians. "Should be faster" is not done.

---

## 5 · The loop, condensed

```
pick        ratio table + history dynamics (§3) → the row with a locatable cause
predict     expected size + disqualifying evidence, written down (§1.3, §3.3)
change      the smallest thing that tests the theory
measure     alternating A/B, 3 rounds, medians (§1.1)
record      append to the history: sha, load, ratio (§2.1)
decide      gain → keep and say the number. no gain → REVERT and record the refutation
re-read     did the table's shape change? does the next row still look the same? (§3)
```

The step agents skip is **revert and record**. A change that measured nothing is not
harmless: it is future reading, future conflict, and a thing someone must understand before
touching that code. Drop it, and write down that it was tried.
