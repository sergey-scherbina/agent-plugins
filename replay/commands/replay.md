---
description: "How to turn a one-off agent failure into something you can re-run: record a run's model replies and tool results to a journal, then replay it with no gateway and no model (strict), replay the PLAN against today's world with tools running for real (live-tools), or FORK at the divergence and carry the run forward with a live model into a new journal. Also covers recording a client that owns its own loop (Claude Code) at the GATEWAY, and why MCP cannot do that. Use when a run failed once and you need it reproducible, when verifying a fix against a recorded failure, when rebasing a run onto a fixed tree, when writing a regression test for the agent loop, or when an AGENTS.md references this file."
argument-hint: "record | replay | live-tools | fork | when-to-use"
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

## 1. The three modes, and which question each answers

| Mode | Model | Tools | Needs a gateway | Answers |
|---|---|---|---|---|
| **strict replay** | journal | journal | no | "does the agent LOOP still behave the same, given identical inputs?" |
| **live-tools replay** | journal | **real** | no | "does the plan that failed still fail against today's tree?" |
| **fork** | journal, then **live** | **real** | yes, from the fork on | "carry the run forward onto today's world, and give me the new run as a journal" |

Strict touches nothing: no gateway, no network, no tools, no writes. It is the mode
for a regression test — the same run reproduces forever, and it runs in CI with no
model at all.

Live-tools is for the fix loop. The model's decisions stay pinned to the recording
while the tools actually execute, so you can land a fix and ask whether the *same*
plan now gets a different answer from the world.

Fork is live-tools that does not stop. **Read it as rebase for agent runs**: the
prefix that still matches costs no model calls at all, and you pay for the model only
from the point where the world actually moved. What comes out is a complete new
journal — replayed prefix, a note saying why it stopped being a replay, then the live
continuation — which replays strictly like any other. That is the mode that turns "I
fixed the cause of step 12" into a new 30-step baseline without re-paying for steps
1–11.

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

Fork mode is sound for the *same* reason, applied the other way: it does not reuse the
old journal's later turns either. At the fork it abandons that journal entirely and
lets a live model see the new result — which is the question worth asking once the
world has moved. So neither mode ever hands a model reply to a question it was not
answering; one stops, the other asks again.

## 3. Using it from the CLI

```bash
# Record a real run. Nothing records by default; this is always explicit.
# `auto` puts it in .rozum/runs/<id>.jsonl and prints the id; a path still works.
nadia run "<task>" --workspace <dir> --record auto

# Strict: same run, no gateway, no model, no tools. Prove it by pointing --gateway
# somewhere unreachable — if it still produces the same answer, nothing called out.
nadia run "<task>" --workspace <dir> --replay run.jsonl --gateway http://127.0.0.1:1

# Live-tools: the plan from the journal, the tools for real.
nadia run "<task>" --workspace <dir> --replay run.jsonl --replay-live-tools

# Fork: same, but continue live at the divergence and write the new run out.
nadia run "<task>" --workspace <dir> --replay <id> --replay-fork auto

# What has been recorded here, and what came from what.
nadia runs list
nadia runs rm <id>
```

`--replay` takes an **id or a path**: an existing file is used as-is, anything else is
looked up in `.rozum/runs`. So the id `runs list` prints can be pasted straight back.

`--replay-fork` reports which of the two things happened, and both are useful: it
either forked (the world moved — the new journal's own note says where and why), or it
did not (today's tree still answers exactly as the recording did, and the new journal
is a faithful copy).

Refused rather than silently ignored: `--record` together with `--replay`, either of
them outside `nadia run`, `--replay-live-tools` or `--replay-fork` without `--replay`,
and the two of them together (they answer opposite questions about the same
divergence, so picking one silently would be wrong).

**Three things that will bite you if nobody says them:**

- **Replay with the same `--workspace`.** The workspace path is in the system prompt,
  the system prompt is in the model-call fingerprint, so a different path is a
  different run and the replay refuses. That refusal is correct; it is just
  surprising the first time.
- **Offer the same tools.** Tool NAMES are in the model-call fingerprint too, so
  replaying with a different tool set (or with MCP servers connected that were not
  connected when recording) is a different run and is refused for the same reason.
- **The acceptance gate is skipped under `--replay`, and says so.** The gate makes its
  own model calls, which the journal never recorded — running it would reach for a
  gateway in the one mode whose whole promise is that it does not. A replay is not a
  verified run.

## 4. Recording a client that owns its own loop (Claude Code)

Everything above assumes the agent loop is ours. When it is not — Claude Code runs its
own loop and dispatches its own `Bash`/`Read`/`Edit` — none of those decorators have
anywhere to sit. **MCP does not help here**: an MCP server sees calls to its own tools
and never a single model reply, so it can supply neither half of a journal.

The gateway can, but only for a client it actually serves:

```bash
rozum gateway record start          # journal every model call, prints the run id
rozum gateway record status
rozum gateway record replay <id>    # answer from the journal instead of the model
rozum gateway record stop
```

It is live: a session already talking to the gateway starts being recorded without a
restart under it. `ROZUM_GATEWAY_RECORD=auto` covers the launch path, where the gateway
is spawned for one session and nobody can call the endpoint first. Journals land on the
same `.rozum/runs` shelf, so `nadia runs list` shows them next to agent runs.

**Three limits worth knowing before you rely on it:**

- **Only for a rozum-served model.** On upstream Anthropic there is no gateway in the
  path at all, so a Claude Code session on Anthropic's models cannot be recorded by
  rozum — not a gap in this feature, simply nothing of rozum's is in that path.
- **Always the live-tools shape.** The client runs its own tools; the gateway sees their
  results only as text in the next request. So the first tool result that differs changes
  that request and diverges, loudly. Useful for "where did today's world stop matching",
  useless as a regression test of the client's loop.
- **Replay still holds a model lease.** The switchboard is entered before the
  interception, so a replaying gateway does not generate but is not a way to run with no
  model resident.

## 5. Where journals live, and how a fork is traceable

Journals belong in `.rozum/runs/<id>.jsonl` — the same per-project directory the RAG
index and the task state already use. Ids are `<unix-seconds>-<short-hash>`, so `ls` is
chronological and two runs in the same second do not collide.

Each journal's **first line is a header**: the task, the workspace, the model, when, and
— for a fork — the parent's id. That is what makes `nadia runs list` cheap (it reads one
line per file, not the whole transcript) and what gives a fork machine-readable lineage:

```
1788422548-3da9af    12 entries  create hello.txt  forked from 1788422537-79d9f8 (6 entries)
1788422537-79d9f8     6 entries  create hello.txt
```

Two details worth knowing rather than discovering:

- The header's `parent_entries` is **how long the parent was**, not where the fork
  happened — the header is written before the run starts, when that is still unknown.
  The precise fork point is in the fork's own note, written when it actually happens.
- A journal with no header still appears in the listing, with empty fields. Hiding it
  would make the list lie about what is on disk.

The header is invisible to a replay: it matches no call, so a journal that has one
replays exactly like one that does not.

## 6. What a journal proves, and what it does not

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

## 7. Treat the journal as sensitive

It holds everything: the system prompt, the user's words, every model reply, every
tool result. It is exactly as sensitive as the session it recorded. Recording is
explicit, nothing records by default, and the file is yours to keep or delete
(`nadia runs rm <id>`)
— the same rules `meeting::repro` already states for incident bundles. Do not commit
one into a repo without reading it first.

## 8. Where this fits the other skills

- [`isolate`](../../isolate/commands/isolate.md) — its "make it deterministic" step is
  this. Record the flaky run, then bisect against a journal instead of against a
  system that answers differently every time.
- [`bugs`](../../bugs/commands/bugs.md) — a journal is the strongest possible repro to
  attach to a `BUGS.md` entry: not a description of the failure, the failure itself.
  Land the fix, then replay with `--replay-live-tools` and read where it now diverges.
