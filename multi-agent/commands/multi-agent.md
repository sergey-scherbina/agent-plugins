---
description: "Multi-agent coordination for parallel feature-branch work. Use when checking coordination status across agents, claiming tasks from a work queue, triaging a foreign claim, updating a heartbeat, releasing a stale claim, or looking up the claim/heartbeat/triage/worktree protocol. Also triggered when an AGENTS.md references this file for coordination protocol."
argument-hint: "status | claim <slug> | triage <slug> | heartbeat | release <slug>"
---

# Multi-agent coordination

This skill defines the coordination protocol for parallel agents working in
feature branches on a shared `origin/main`. It is compatible with any agent
that can read markdown: load it from `AGENTS.md` or invoke it directly.

**Action dispatch** — determine which section to follow based on your task:

| Task | Section |
|---|---|
| Show current coordination state | [→ status](#status) |
| Claim an unclaimed task from the queue | [→ claim](#claim-slug) |
| Assess a claim you did not make | [→ triage](#triage-slug) |
| Refresh your active claim's liveness signal | [→ heartbeat](#heartbeat) |
| Release an abandoned claim | [→ release](#release-slug) |

For Claude Code: invoked as `/multi-agent [action] [args]` — match the
argument to a row above and follow that section.
For any other agent: read the task description from your context and navigate
to the matching section.

---

## Actions

### status (default)

Show the current coordination state of this repository.

```bash
git fetch origin
git log origin/main --oneline -10
git ls-tree origin/main .work/active/ 2>/dev/null
git worktree list
test -f "$(git rev-parse --show-toplevel)/.work/paused" && echo "PAUSED" || true
```

Print a structured summary:

```
PAUSED: yes/no

Active claims:
  <slug>  agent:<id>  heartbeat:<timestamp> (<N> min ago)  status:<value>

Worktrees:
  <branch>  <path>  [HEAD commit]

Pending tasks (top 5):
  [ ] <slug> — <description>

Stale claims (heartbeat > 20 min):
  <slug>  last heartbeat: <timestamp>
```

A claim is stale if its `heartbeat` field is older than 20 minutes, or if the field is missing.

---

### claim `<slug>`

Claim an unclaimed task. **Must run from the main checkout** (`.git` is a directory, not a file).

1. Verify preconditions:
```bash
test -d .git                                          # must be main checkout
test "$(git symbolic-ref --short HEAD)" = "main"
git fetch origin
git merge --ff-only origin/main
git diff --cached --quiet
git ls-tree origin/main .work/active/ | grep "<slug>" && echo "ALREADY CLAIMED — stop"
```

2. Write the claim file:
```bash
AGENT_ID="claude-code"   # adjust if running as a different tool
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s\nagent: %s\nheartbeat: %s\nstatus: not-started\ndone-so-far:\nnext: (plan first step)\n' \
  "feature/<slug> $TS" "$AGENT_ID" "$TS" \
  > ".work/active/<slug>.claim"
git add ".work/active/<slug>.claim"
test "$(git diff --cached --name-only)" = ".work/active/<slug>.claim"
git commit -m "claim: <slug>"
git push origin main     # if rejected: another agent won the race — fetch and pick a different task
```

3. Create worktree:
```bash
BRANCH="feature/<slug>"
WT=".worktrees/$BRANCH"
git worktree add "$WT" -b "$BRANCH" origin/main
```

4. Immediately update claim to `in-progress` (from main checkout):
```bash
# edit .work/active/<slug>.claim:
#   heartbeat: <current timestamp>
#   status: in-progress
#   done-so-far: worktree created
#   next: <first implementation step>
git add ".work/active/<slug>.claim"
git commit -m "claim-update: <slug> in progress"
git push origin main
# then rebase worktree:
git -C "$WT" fetch origin && git -C "$WT" rebase origin/main
```

---

### triage `<slug>`

Assess a claim you did not make in this session.

```bash
SLUG="<slug>"
MAIN=$(git worktree list | head -1 | awk '{print $1}')
WT="$MAIN/.worktrees/feature/$SLUG"

git show origin/main:.work/active/$SLUG.claim
git worktree list | grep "$SLUG"
git -C "$WT" status --short 2>/dev/null | head -20
git show origin/main:.work/active/$SLUG.claim | grep -E '^(agent:|heartbeat:)'
```

Interpret using this table:

| Worktree | Dirty files | Heartbeat age | Conclusion |
|---|---|---|---|
| missing | — | any | Orphan — safe to release and reclaim |
| exists | no | > 20 min or missing | Likely dead session |
| exists | yes | > 20 min | Work in progress, agent gone — ask user |
| exists | yes or no | **< 20 min** | **Possibly live — do not touch; ask user** |

Report findings in this format and wait for user direction:

```
Active claim: <slug>
  Claimed at: <timestamp>
  Agent: <agent-id / unknown>
  Heartbeat: <timestamp> — <N> min ago / missing
  Worktree: exists / missing
  Uncommitted changes: N files / none
  Status: <value>
  Done so far: <text / unknown>
  Next step: <text / unknown>

Assessment: <one sentence>

Options:
  (a) Review work and continue
  (b) Abandon worktree, release claim, pick next task
  (c) Leave as-is, pick a different task
```

Do not implement anything until the user responds.

---

### heartbeat

Refresh the `heartbeat` timestamp on your active claim. Run this from the **main checkout** whenever uncommitted work has been sitting for more than ~10 minutes.

```bash
SLUG="<your-active-slug>"   # identify from git ls-tree origin/main .work/active/
git fetch origin && git merge --ff-only origin/main
# edit .work/active/$SLUG.claim — update heartbeat field to current UTC timestamp
# also update done-so-far / next if state changed
git add ".work/active/$SLUG.claim"
git commit -m "claim-update: $SLUG heartbeat"
git push origin main
# rebase your worktree:
git -C ".worktrees/feature/$SLUG" fetch origin
git -C ".worktrees/feature/$SLUG" rebase origin/main
```

---

### release `<slug>`

Release a stale or abandoned claim. **Must run from the main checkout.**

```bash
test -d .git
test "$(git symbolic-ref --short HEAD)" = "main"
git fetch origin && git merge --ff-only origin/main
git diff --cached --quiet
git rm ".work/active/<slug>.claim"
git commit -m "release-claim: <slug> (agent gone)"
git push origin main
```

Optionally clean up the orphaned worktree:
```bash
git worktree remove --force ".worktrees/feature/<slug>"
git branch -D "feature/<slug>"
```

---

## Claim file format

Every claim file must use this format (line 1 is backward-compatible with old single-line claims):

```
<worktree-name> <ISO-timestamp>
agent: <agent-id>
heartbeat: <ISO-timestamp>
status: not-started | in-progress | blocked
done-so-far: <one-line summary or empty>
next: <first planned step>
```

**`agent`** — who holds the claim. Use a short identifier: `claude-code`, `codex`,
`claude-opus-4-7`, `claude-sonnet-4-6`, etc. This is the primary signal for
"is this mine or someone else's?"

**`heartbeat`** — last time the agent pushed a live update to `origin/main`.
Refresh on every `claim-update` commit and whenever dirty/uncommitted work
sits for more than ~10 minutes. Older than ~20 minutes → treat as potentially
orphaned.

Old single-line format (`<worktree-name> <timestamp>` only) is still valid;
missing fields default to `unknown`.

---

## Worktree workflow

### One change = one branch = one worktree

Do all edits on a `feature/<name>` branch inside a **git worktree** — never
directly on the shared `main` checkout.

```bash
BRANCH="feature/your-task-name"
WT=".worktrees/$BRANCH"
git worktree add "$WT" -b "$BRANCH" origin/main
# all work from $WT
```

When done:
```bash
git -C "$WT" push origin "$BRANCH:main"   # rebase first if behind
git branch -f main origin/main            # sync local main (mandatory)
git worktree remove --force "$WT"
git branch -D "$BRANCH"
```

`main` is only for:
1. Reading state (`git log`, `git status`)
2. Coordination operations (claims, heartbeats, releases)
3. Fast-forward merge + push of a finished branch

### Absolute-path trap

The most common source of lost work: a tool resolves an absolute path to the
**main checkout** while you are in a worktree. The edit lands on `main`, not
your branch.

Prevention: use relative paths in Write/Edit calls; run `git status` in the
worktree after each edit to verify changes landed there.

Recovery:
```bash
# from main: move leaked file back to worktree
mv <main-path>/<file> <worktree-path>/<file>
git -C <main> restore --staged <file> && git -C <main> restore <file>
# then commit from the worktree
```

### Before starting — sync + check

```bash
git fetch origin
git log origin/main --oneline -10       # what already landed?
git worktree list                       # who is doing what?
git ls-tree origin/main .work/active/  # active claims (authoritative)
```

Always use `origin/main` — not local `git log` — to decide whether a task is done.

---

## Autonomous loop

```
LOOP:
  1. From MAIN CHECKOUT: fetch, ff-merge, check paused flag, re-read AGENTS.md
  2. Read origin/main:WORK_QUEUE.md + ls .work/active/ — pick top unclaimed task
  3. Claim (from main checkout) → push → if rejected go to 1
  4. Create worktree; update claim to in-progress
  5. Implement → run tests → fix until green
     At each intermediate commit and every ~10 min of dirty work:
       update heartbeat + done-so-far + next → push claim-update to origin/main
       rebase worktree on origin/main
  6. Update docs (feature spec, SPEC.md, openapi if needed)
  7. Bookkeeping commit: remove claim, move task to Done in WORK_QUEUE.md
  8. Push to origin/main; sync local main; delete worktree + branch
  9. Report "✓ <slug>: <summary>" BEFORE starting next iteration
 10. Go to 1
```

Stop conditions: `.work/paused` on `origin/main`, user stop signal, `status: blocked`.

---

## Coordination rules summary

- Claims are valid **only when visible on `origin/main`** — a local file or
  a commit on a feature branch is not a claim.
- Never assume a claim is yours because it exists — read `agent:` first.
- Heartbeat > 20 min = potentially orphaned; run `triage` before touching.
- Never `git reset --hard`, `git stash`, or `git restore .` on shared `main` —
  these destroy sibling agents' work.
- The absolute-path trap is the #1 source of lost work in worktree sessions.
