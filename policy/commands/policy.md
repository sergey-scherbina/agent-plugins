---
description: "Work-management policy for a repository where several agents commit to one main branch. Use when setting a project's policy up for the first time, when a rule about claiming / boards / where a record goes / what a gate must prove is unclear or contested, when you are about to change such a rule, or when an AGENTS.md points here. Core rule: a rule is stated in ONE file, everywhere else links to it."
argument-hint: "init | check | cite <rule> | contest <rule>"
---

# Policy — one source for how work is managed

This skill is agent-independent: plain markdown about a discipline. It has two halves.

**Part A** is the policy itself, in generic form. It is what any repository with several
agents committing to one `main` needs, and it is written so it can be adopted as-is.

**Part B** is how a concrete project *instantiates* it — the handful of things Part A
deliberately leaves open (module list, file names, tool names, channel), and the checklist
for filling them in.

The policy exists because of one repeated, measurable failure: **duplicated state with no
invariant.** Two copies of a rule, a list, or a scope drift, and nobody notices until the
drift causes wrong work. Every rule below is a consequence of that, or of its twin —
**apparatus that is green because it cannot see.**

---

## Part A — the policy, generic

Adopt this into a single file at the repository root. `POLICY.md` is a good name; the name
matters less than there being exactly one. Number the rules so they can be cited in a
commit message or a review: "P-3.5" should be unambiguous.

### P-1 · The loop

Every piece of work, in this order:

1. **Claim first — before planning.** Planning takes minutes and that whole window is a
   race. A claim is one cheap, revocable commit.
2. **Plan into the queue** for the module you are touching, and make the work visible on
   whatever answers *what is happening right now*.
3. **Work in an isolated checkout** (a worktree, a branch) named after the claim, so the
   scope guard can find the claim from the branch.
4. **Verify, then integrate.** Small commits; feature separated from bookkeeping. The
   affected test slice runs *before* integration, not after. A user-facing change ships
   with its documentation in the same push.
5. **Release and clean up** with a tool, not by hand.
6. **Read the coordination channel** every time you finish an item and have nothing in
   flight.

### P-2 · Claims

- **Claim the narrowest scope that covers the work.** A whole-subtree reservation should
  cost you a written justification. *Measure this in your own repo before arguing about
  it:* count files reserved against files changed. A ratio near 99% is normal and is the
  argument.
- **A subtree claim is an EDIT LOCK, not stewardship.** "This area is mine" is a different
  statement from "nobody may touch these 1000 files", and conflating them is what makes
  agents over-reserve.
- **Never claim a bookkeeping file.** Boards, changelogs and issue files are appended to by
  everyone by design; make the guard exempt them by BASENAME so per-module copies are
  exempt too. A rebase conflict there is cheap; a refusal is not.
- **Widening a claim is a normal move, not a failure.** Nobody can predict their path set
  before reading the code. Make widening cheap — one command — rather than making people
  guess better. If scope is stored in two places, the guard must refuse when they disagree.
- **A claim exists when it is visible to everyone**, not when you write the file locally.
- **Deliberate re-checking of another agent's result is legitimate**, and should be
  claimable as such (`verify-<slug>`), so the mutex targets *accidental* duplication only.
- **A refusal you believe is wrong is a conflict of interest** → the channel (P-5), never a
  force-push and never releasing someone else's claim. **A stale heartbeat is not
  liveness** — check for recent commits before concluding anyone is gone.

### P-3 · Where work is recorded

- **One set of boards per module, inside the module.** A file exists only where there is
  something in it; creating empty ones manufactures the appearance of coverage.
- **An entry belongs to the module where the FIX goes** — not where the symptom appeared,
  not where the gate lives. This is the hard one, and getting it wrong is systematic rather
  than careless.
- **Authority for classifying an entry, in order:** a resolvable commit reference > a field
  a human declared > extraction from prose (**never**). Prose extraction produces a field
  that looks classified and is not — expect a plurality of entries to collapse onto
  whichever word is most common in your domain.
- **Machine-readable header, human-readable body.** Put `status`, and whatever else you
  query, in a parsed header. **Never grep for status**: prose will grow three synonyms for
  "closed" and a long tail of entries with none.
- **Derived state is generated, never maintained.** If one copy can be computed from
  another — a board from the claims, an index from the entries — generate it and check the
  generated form. A consistency gate is the right fix only when both copies are
  independent.
- **Subtype is a FIELD, not a second directory.** `kind: bug|perf|feature|…` on the entry;
  per-type documents carry a *generated* index plus hand-written analysis. A second axis in
  the filesystem gives an entry two plausible homes, and then "no duplicates" stops holding
  and "in neither" becomes possible.

### P-4 · Deciding

- **Default to deciding.** If you can name a defensible default and the cost of being wrong
  is a revert, take it and say so in the commit.
- **When the fork is real, take the smallest defensible option and PARK the alternatives**
  with their trade-offs. A parked alternative costs nothing and is there the day it becomes
  right; the same alternative held as "I should ask" is lost at the next reboot.
- **Ask anyway** for something irreversible or outward-facing, a decision that invalidates
  shipped work, a genuine conflict between two instructions, or every-option-is-bad — and
  **keep working on everything that does not depend on the answer.**

### P-5 · The coordination channel

- **One channel.** A conflict is only visible if everyone looks at the same place.
- **Contested goes there:** another agent's claim in your way, a claim you believe
  over-reserves, two defensible answers where the choice affects others, any change to a
  shared contract.
- **Not there:** a report of what you did, a finding that belongs in a tracker, or a
  question you could answer with one command. **Measure first, then ask.**
- **The channel must be READ, not only written.** Posting is the cheap half. Make sweeping
  it a fixed checkpoint in the loop, not a judgement call — the failure is invisible from
  the poster's side.
- **State what you will do if nobody answers.** A question with no default attached blocks
  you, and blocking is what the channel exists to avoid.
- **Addressability must not depend on ownership.** If agents are addressed by claim, an
  agent holding no claim — because it just finished, or came to ask before starting — does
  not exist in the channel. Allow a stable handle too.

### P-6 · Apparatus

The most expensive recurring defect is not broken code. It is **a check that is green
because it cannot see.**

- **A gate must be observed FAILING before it is trusted.** Revert the fix, run the gate,
  put the red count in the commit. A gate nobody has seen fail is a hypothesis.
- **A gate about a TOOL must RUN that tool.** Checking the files a tool writes covers
  neither a crash nor a syntax error.
- **A filter must say what it did NOT read.** A query over one of three data sources looks
  complete and is not.
- **Duplicated logic needs one vocabulary on both sides**, or it is not one guard but two.
  Expect drift between layers of the same check; test both layers.
- **State the expected size before starting, and record refuted attempts.** Without the
  record, a plausible-but-wrong idea gets retried, because it looks obviously right.
- **One measurement is a hypothesis.** See the `performance` skill for the protocol.

### P-7 · The policy file itself

- **A rule is stated once.** Everywhere else links to it. If you find a rule restated, the
  fix is to replace it with a link, not to keep both in sync.
- **Mechanism, evidence and history stay in the specs.** They are why the rule exists, and
  they are too long to live beside it.
- **A citation names the SUBJECT, not the CONTENT.** "When a doc update is required is
  P-1.4" is a signpost. "A feature with no doc update is incomplete — see P-1.4" is a
  second copy wearing a link. This distinction is what a duplication gate cannot make, so
  it has to be written down for reviewers.
- **Changing a rule is a shared-contract change** → P-5 first.

---

## Part B — instantiating it in a project

Part A is deliberately silent about names. These are the decisions a project must make, and
**writing them down is the instantiation**. Nothing else is required.

### B-1 · The slots to fill

| Slot | What it is | Typical |
|---|---|---|
| **policy file** | where the rules live, one file | `POLICY.md` at the root |
| **module list** | the units of code AND ownership | a machine-readable table, not prose |
| **boards** | per-module record files | `{BUGS,BACKLOG,SPRINT}.md` per module |
| **in-flight view** | what is happening right now | generated from the claims |
| **claim store** | where claims are visible to all | a directory on `main` + a ledger |
| **claim tool** | writes claim + ledger + bumps a counter | `coord-claim` / `coord-release` |
| **scope levels** | the granularity vocabulary | `file:` / `mod:` / `repo:` |
| **guards** | what enforces the scope, and at which layers | pre-commit + pre-push |
| **channel** | the one coordination room | a chat room, an issue, a file |
| **header schema** | the parsed fields on an entry | `status`, `kind`, plus your own |
| **gates** | how a rule is checked | one script per rule, each with a self-test |

**The module list must be machine-readable and have exactly one copy.** It is read by the
claim tool, the record router and the boards; a prose list in a spec will be duplicated
within a week and then disagree with itself.

### B-2 · The order to build it in

Build in this order, because each step's failure is only visible once the previous exists.

1. **The claim store and its mutex.** The mutex is a monotonically bumped counter in a
   single shared file — that is what makes two concurrent claims *collide* instead of
   auto-merging into disjoint files. Without it, the loser of a race never learns the
   winner exists.
2. **The scope guard, at every layer.** Two layers (commit-time and push-time) is normal;
   they must share one vocabulary. Test both.
3. **The boards and the routing rule.** Route by where the fix goes; verify the routing
   with a check, because it will be wrong.
4. **Generate whatever is derivable.** Then delete the consistency gate that watched the
   copy you no longer keep.
5. **The policy file, and the gate that keeps it single.**

### B-3 · Instantiation checklist

```
[ ] every slot in B-1 has a named artifact in this repo
[ ] the module list exists once, machine-readable, and something reads it
[ ] the claim tool bumps a shared counter (verify: two concurrent claims CONFLICT)
[ ] scope guards exist at every layer and share one vocabulary (verify: test each layer
    with a MODULE-level path, not only a root-level one — this is where they drift)
[ ] a gate exists for each rule that can be checked mechanically, each with a self-test
    that proves it can go red
[ ] the policy file's rules are numbered
[ ] every entry-point document links to the policy file and states which half lives where
[ ] a gate asserts no rule is stated in two places
[ ] AGENTS.md (or equivalent) points at the policy file in its first paragraph
```

### B-4 · What a gate over the policy can and cannot do

It can check two things, and both are decidable: **a rule's distinctive phrase appears
exactly once** across tracked documents, and **every entry-point document links to the
policy file**.

It cannot detect a paraphrase. Deciding whether two paragraphs state the same rule is not
mechanical, and a keyword heuristic there is precisely the "extraction from prose" mistake
P-3 warns about. **Say this in the gate's own header.** Green means "no verbatim copy and
the pointers resolve", not "no rule is restated" — and the difference has to be visible to
whoever reads the green.

Give the two failures distinct messages: *phrase not found at all* means the GATE is stale
(the rule was legitimately rewritten); *stated in N places* means the REPO is. The first
instinct on a red gate is to assume the repo is wrong, and half the time it is not.

### B-5 · Adopting into a repo that already has rules scattered

Do not copy the rules into the new file — that manufactures one more copy of the thing you
are fixing. **Move them.** For each source document:

1. **Find the rules that exist ONLY there and move those FIRST.** This is the whole risk of
   the exercise. A gate that pins duplicated phrases cannot see a rule that exists once and
   is about to be deleted.
2. Reduce each section to *citation + mechanics*: the rule becomes a `P-n` reference that
   names the subject; the commands, flags, failure modes and measurements stay.
3. Verify **by probe, not by eye**: take every distinctive phrase from the old sections and
   assert each still resolves somewhere. Eyes miss exactly the sentence that mattered.
4. Check the reduced document still works alone — a reader following only it must still be
   able to do the work.
