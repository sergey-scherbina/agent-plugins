---
description: "How to turn a one-off agent failure into something you can re-run: record a run's model replies and tool results to a journal, then replay it with no gateway and no model (strict), or replay the PLAN against today's world with tools running for real (live-tools). Use when a run failed once and you need it reproducible, when verifying a fix against a recorded failure, when writing a regression test for the agent loop, or when an AGENTS.md references this file."
argument-hint: "record | replay | live-tools | when-to-use"
---

# replay — turn "it failed once last night" into something you can run again

This skill is agent-independent: plain markdown about a discipline, usable by any
agent that reads it — load it from `AGENTS.md` or invoke it directly. It is the
missing half of [`isolate`](../../isolate/commands/isolate.md): that skill is about
finding a cause in a live system, this one is about *pinning the run down* so the
cause stops moving while you look at it.

**The idea in one sentence:** an agent run has exactly two nondeterministic inputs —
what the model said, and what a tool answered — so journaling both, in call order, is
enough to re-run the whole loop later.

## 1. The two modes, and which question each answers

| Mode | Model | Tools | Answers |
|---|---|---|---|
| **strict replay** | journal | journal | "does the agent LOOP still behave the same, given identical inputs?" |
| **live-tools replay** | journal | **real** | "does the plan that failed still fail against today's tree?" |

Strict touches nothing: no gateway, no network, no tools, no writes. It is the mode
for a regression test — the same run reproduces forever, and it runs in CI with no
model at all.

Live-tools is for the fix loop. The model's decisions stay pinned to the recording
while the tools actually execute, so you can land a fix and ask whether the *same*
plan now gets a different answer from the world.

## 2. Why live-tools STOPS instead of continuing

The obvious design would be "let the tools be live and carry on" — a weaker isolation
level, in the database sense. That analogy is where the mode came from and it is worth
stating why it only half applies.

A weaker DB isolation level tolerates an anomaly in exchange for concurrency. **This
anomaly cannot be tolerated.** The journal's next model turn was produced while the
model was looking at the OLD tool result. The moment a live tool answers differently,
every model reply after it in the journal is an answer to a question this run is no
longer asking. Continuing would not give you a weaker guarantee — it would give you a
confidently wrong run, which is the one outcome worse than no run at all.

So the mode detects rather than tolerates:

1. the tool **call** must still match the journal (the model is being replayed, so it
   must be asking the same thing — a mismatch here means the *plan* diverged, and no
   live tool is executed for it);
2. the tool then runs **for real**;
3. same result as the recording → the run continues, still sound;
4. different result → **stop**, naming the tool, what it returns now, what the
   recording had, and how far the plan replayed identically.

**The stop is the answer, not a failure to finish.** "Where did reality stop matching
the recording" is exactly the question the fix loop is asking.

## 3. Using it from the CLI

```bash
# Record a real run. Nothing records by default; this is always explicit.
nadia run "<task>" --workspace <dir> --record run.jsonl

# Strict: same run, no gateway, no model, no tools. Prove it by pointing --gateway
# somewhere unreachable — if it still produces the same answer, nothing called out.
nadia run "<task>" --workspace <dir> --replay run.jsonl --gateway http://127.0.0.1:1

# Live-tools: the plan from the journal, the tools for real.
nadia run "<task>" --workspace <dir> --replay run.jsonl --replay-live-tools
```

Refused rather than silently ignored: `--record` together with `--replay`, either of
them outside `nadia run`, and `--replay-live-tools` without `--replay`.

**Two things that will bite you if nobody says them:**

- **Replay with the same `--workspace`.** The workspace path is in the system prompt,
  the system prompt is in the model-call fingerprint, so a different path is a
  different run and the replay refuses. That refusal is correct; it is just
  surprising the first time.
- **The acceptance gate is skipped under `--replay`, and says so.** The gate makes its
  own model calls, which the journal never recorded — running it would reach for a
  gateway in the one mode whose whole promise is that it does not. A replay is not a
  verified run.

## 4. What a journal proves, and what it does not

It proves the agent's **own calls** replay: same messages out, same events back, same
tool arguments and results, same order. Divergence is loud — every entry carries a
fingerprint, and a call that does not match the next entry fails with both
fingerprints rather than answering a different question. Running past the end of the
journal is a divergence too.

It does **not** prove the world underneath is unchanged. In strict mode the journal
holds what a tool *returned*, not the file it read — replaying against a changed tree
gives you the old answer and hides the change. That boundary is deliberate (journaling
every byte a tool touched is a much larger feature), and live-tools mode exists
precisely for the times you need to ask about the world instead.

## 5. Treat the journal as sensitive

It holds everything: the system prompt, the user's words, every model reply, every
tool result. It is exactly as sensitive as the session it recorded. Recording is
explicit, nothing records by default, and the file is yours to place, keep and delete
— the same rules `meeting::repro` already states for incident bundles. Do not commit
one into a repo without reading it first.

## 6. Where this fits the other skills

- [`isolate`](../../isolate/commands/isolate.md) — its "make it deterministic" step is
  this. Record the flaky run, then bisect against a journal instead of against a
  system that answers differently every time.
- [`bugs`](../../bugs/commands/bugs.md) — a journal is the strongest possible repro to
  attach to a `BUGS.md` entry: not a description of the failure, the failure itself.
  Land the fix, then replay with `--replay-live-tools` and read where it now diverges.
