---
description: "How to debug a flaky failure in a real multi-component system (model × agent × gateway × sandbox × tooling): look before guessing, bisect into isolated halves, make it deterministic, and prove our-bug-vs-model. Use when a benchmark/matrix cell fails intermittently, when a symptom has several plausible causes, or when you're tempted to blame the model."
argument-hint: "look | bisect | determinize | our-bug-vs-model"
---

# Isolate — debug a real system, don't guess at it

This skill is agent-independent: plain markdown about a discipline, usable by any
agent that reads it — load it from `AGENTS.md` or invoke it directly. It is the
companion to [`bugs`](../../bugs/commands/bugs.md) (which is about *tracking* a
bug); this one is about *finding the cause* when the failure lives inside a stack
of interacting components and looks like noise.

A "real system" here means a chain like **model → agent (codex/opencode/claude) →
gateway → sandbox → shell tooling (`patch`, `cargo`, …)**. When a cell fails — a
matrix run times out, a `pass` flips 0/1 between runs — the cause can be in *any*
link, and the links interact. The instinct to say "the small model is just bad"
is usually wrong and always untested. Here is the discipline that works.

## 1. Look before you guess

Read the **actual transcript of the actual failing run**, line by line, to the
end. Not a hypothesis about it. The cause is almost always visible in the bytes.

- Read **both ends**: the agent log (rendered tool calls + results) *and* the
  gateway/server log (the raw model completion before the agent reshaped it).
  They tell different halves — the agent log shows what *ran*, the gateway log
  shows what the *model emitted*.
- A plausible-sounding cause you can't point at in the log is a **red herring**.
  (Real example: a sandbox egress error to `chatgpt.com/backend-api/...` looked
  causal; reading on, it fired once at startup and never touched the edit loop.)
- Beware "it fixed itself" and "it's just the model": both are excuses to stop
  reading. Keep reading until the failing mechanism is a specific line.

## 2. Bisect into isolated halves

Remove one variable at a time. Each component can usually be exercised **without
the ones above or below it**:

- **Tool only — no model, no agent.** Replay the exact command the gateway built
  (`patch …`, `cargo run`, the shell line) by hand on a seeded file. This is the
  cheapest, most deterministic probe and it catches *gateway/tooling* bugs that
  have nothing to do with the model. (Real example: replaying the gateway's
  `patch -p0 --fuzz=3` twice by hand reproduced a fix being silently **reverted**
  on the second apply — a one-line gateway bug, proven with zero model calls.)
- **Model only — no agent.** Send the exact prompt + tool schema straight to the
  gateway `/v1/chat/completions` and read the raw output. Tells you what the
  model actually emits (shapes, malformations, whether it knows to stop),
  separate from how the agent renders/executes it.
- **Agent only — mock model.** Point the agent at a stub server that returns a
  *fixed* scripted reply. Now the agent/gateway behavior is deterministic and you
  can see exactly how it handles a known-good or known-bad model output, with the
  model's variance removed.
- **Sandbox on/off, same everything else.** If a failure only happens jailed,
  test whether the jail blocks a real syscall (run the suspect command *inside*
  the profile) before assuming it does. (Real example: the sandbox was blamed for
  a loop; the profile actually allowed `process-exec*` and `cargo run` ran fine
  jailed — the jail was exonerated.)

Compare a passing run against a failing run of the *same* cell and diff what they
did. The first divergence is your lead.

## 3. Make it deterministic

Variance hides bugs. A `pass` that flips 0/1 is not "flaky and unknowable" — it
is a deterministic mechanism plus a coin you haven't found yet. Drive toward a
**reproduction that fails the same way every time**, usually by collapsing to the
tool-only probe (step 2). Once it's deterministic, the cause is undeniable and
the fix is provable. (Real example: the 0/1 `pass` flip was a file *oscillating*
fixed↔buggy as the model re-sent a patch; the timeout froze a random state. The
deterministic core was two hand-runs of `patch`.)

Quantify before you fix: **count the shapes** in the raw output. Fix the dominant
case, not the eye-catching rare one. (Real example: a malformed lowercase patch
header showed up 2× while the *correct* header re-sent 50× was the real driver —
fixing the rare shape would have moved ~4% of cases.)

## 4. Prove our-bug-vs-model

The central question is almost always: **is this our bug, or a model limitation?**
Separate them with a control:

- Take the model's exact output and run it through the deterministic harness by
  hand. If it *still* fails → it's **our bug** (gateway/agent/tooling), and no
  amount of "use a bigger model" fixes it.
- If a known-good output runs clean through the same path but the model's does
  not → characterize the model's defect precisely (which shape, how often), then
  decide: translate/repair it at the boundary, or accept it.
- **Don't change the model's interface to dodge the question.** Translating the
  model's output is fair; redesigning the tool surface to force different output
  usually backfires. (Real example: injecting a "cleaner" tool schema made a
  reasoning model *worse* — 3/5 → 0/5.)

Hold the two apart in the writeup, too. A single symptom often hides **two
independent bugs** — e.g. a correctness bug (wrong final state) and a termination
bug (won't stop). Fix them separately; don't let one mask the other.

**"It's a weak model" is the most seductive premature conclusion — isolate before
you say it.** (Real example: a freshly-ported model scored 4/15 on the agentic
matrix, narrating tool use in markdown prose instead of emitting structured tool
calls; the easy read was "this model isn't tool-tuned, unfixable." Wrong. Model-only
probes — the same tools sent straight to the gateway with a *clean* prompt, across
every endpoint — returned perfectly structured calls. The failure only appeared with
the **agents' large system prompts**, which instruct "explain in prose + use markdown
before each call"; the model *faithfully followed that* into markdown narration. A
control — the gold-standard model on the same agent prompts — stayed structured. So
it was a prompt-conflict, prompt-triggered and fixable (constrain the decode / strip
the narration framing), not an inherent model limit. The "look before you guess" rule
applies hardest to the model itself: never close a cell as "model too weak" until a
clean-prompt model-only probe has been run.)

## 5. Prove the fix in isolation before you ship it

The same discipline that found the bug validates the fix. Reproduce the
deterministic failure, apply the change, show it now passes deterministically —
*before* committing. A fix shipped on a hunch can regress silently. (Real
example: a broad "grab the patch from any field" change shipped without a
deterministic A/B and quietly dropped `pass` to 0 across the board; it was
reverted. The narrow, isolation-proven one-flag fix held.)

---

### Checklist

- [ ] Read the failing transcript to the end — agent log **and** gateway log.
- [ ] Named the failing mechanism as a specific line, not a hypothesis.
- [ ] Reproduced it with the fewest components (ideally tool-only, no model).
- [ ] Made it deterministic; found the coin behind any 0/1 flip.
- [ ] Counted shapes; targeting the dominant case.
- [ ] Settled our-bug-vs-model with a control.
- [ ] Separated independent bugs (correctness vs termination vs …).
- [ ] Proved the fix on the deterministic repro before committing.
- [ ] Recorded the finding ([`bugs`](../../bugs/commands/bugs.md) / spec / memory)
      so the next agent doesn't re-derive it.
