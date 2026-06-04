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

## Configuration

Three keys in `AGENTS.md` configure the pipeline files:

```yaml
SPRINT: WORK_QUEUE.md    # work queue agents pick from     (default: SPRINT.md)
BACKLOG: BACKLOG.md      # long-term backlog               (default: BACKLOG.md)
CHANGELOG: CHANGELOG.md  # append-only completion record   (default: CHANGELOG.md)
```

Resolve all three before every status check or loop step:

```bash
_AGENTS="$(git show origin/main:AGENTS.md 2>/dev/null)"

SPRINT="$(echo "$_AGENTS" | grep -m1 '^SPRINT:' | awk '{print $2}')"
# backward-compat: old prose pattern
[ -z "$SPRINT" ] && SPRINT="$(echo "$_AGENTS" | sed -n 's/^\*\*Queue file for this project:\*\* `\([^`]*\)`.*/\1/p' | head -1)"
SPRINT="${SPRINT:-SPRINT.md}"

BACKLOG="$(echo "$_AGENTS" | grep -m1 '^BACKLOG:' | awk '{print $2}')"
BACKLOG="${BACKLOG:-BACKLOG.md}"

CHANGELOG="$(echo "$_AGENTS" | grep -m1 '^CHANGELOG:' | awk '{print $2}')"
CHANGELOG="${CHANGELOG:-CHANGELOG.md}"
```

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
git diff --quiet
git diff --cached --quiet
git ls-tree -r --name-only origin/main .work/active/ 2>/dev/null | grep -Fx ".work/active/<slug>.claim" && echo "ALREADY CLAIMED — stop"
```

2. Write the claim file:
```bash
AGENT_ID="claude-code"   # adjust if running as a different tool
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .work/active
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

Each project's `AGENTS.md` may add project-specific status format, queue file names, and empty-queue examples. The generic protocol is here.

### Status command

When the user asks for status ("статус", "status", "план", "что делаем"):

1. `git fetch origin`
2. Resolve `$SPRINT`, `$BACKLOG`, `$CHANGELOG` (see §Configuration)
3. `git show origin/main:"$SPRINT"` + `git ls-tree origin/main .work/active/`
4. Print a structured summary — **do NOT start working**

```
ACTIVE: <slug> — <description>    ← or "nothing active"

Pending: N tasks
  <slug> — <description>
  ...

Next up: <slug> — <one-line description>
```

Name the one task you recommend doing next, with a short reason.

### Starting

| Phrase | Meaning |
|---|---|
| "работай" / "go" / "start" | Start from the top of the queue |
| "продолжай" / "continue" | Resume — skip done tasks, pick next pending |
| "работай над X" / "do X" | Start with specific slug, then continue |

Announce the first claimed task before any work:
```
▶ <slug> — <one-line description>
```
Work silently. On each completion:
```
✓ <slug> — <one-line summary>
▶ <next-slug> — <description>   ← omit if stopping
```

### Stopping

**Graceful:** "стоп" / "stop" / "pause" / "хватит" / "достаточно" — finish current task then stop.

**Immediate:** "стоп сейчас" / "stop now" / "abort" — stop at next safe checkpoint. If work is green, commit and push before stopping; if red, leave worktree open and report.

**File-based pause** (survives context rotations, works across agents and sessions):

```bash
# Pause:
touch .work/paused
git add .work/paused && git commit -m "pause: autonomous queue"
git push origin main

# Resume:
git rm .work/paused && git commit -m "resume: autonomous queue"
git push origin main
```

Checked at step 1 of every iteration. A chat message only stops the current session; file-based pause is the reliable mechanism for unattended stops.

### The loop

> **⚠️ CRITICAL** — steps 1–4 and 9–11 MUST run from the **main checkout** (where `.git` is a directory, not a file). Inside a worktree, `git commit` writes to the feature branch, so the claim file never reaches `origin/main` — another agent will pick the same task.

```
LOOP:
  1.  # ── Main checkout ──
      test -d .git && test "$(git symbolic-ref --short HEAD)" = "main"
      git fetch origin && git merge --ff-only origin/main
      git diff --quiet
      git diff --cached --quiet
      Re-read AGENTS.md from origin/main — apply any updated rules
      git ls-tree origin/main .work/ | grep -q paused → STOP
      if user sent stop signal → STOP

  2.  Resolve $SPRINT/$BACKLOG/$CHANGELOG from origin/main:AGENTS.md (see §Configuration)
      git show origin/main:"$SPRINT"         # pending list (authoritative)
      git ls-tree origin/main .work/active/  # claimed slugs (authoritative)
      # Never: cat "$SPRINT" or ls .work/active/ — those may be stale
      if no unclaimed pending tasks → see §"Empty queue"

  3.  Pick highest-priority unclaimed pending task.
      if genuinely ambiguous → ask ONE clear question, wait, then proceed.

  4.  # ── Claim — main checkout only ──
      mkdir -p .work/active
      printf '%s\nagent: %s\nheartbeat: %s\nstatus: not-started\ndone-so-far:\nnext: %s\n' \
        "<worktree-name> <timestamp>" "<agent-id>" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "<first step>" \
        > .work/active/<slug>.claim
      git add .work/active/<slug>.claim
      git commit -m "claim: <slug>"
      git push origin main
      if push rejected → go to 1

  5.  Create worktree off updated origin/main.
      Push claim-update (status: in-progress, done-so-far: worktree created)
      from main checkout, then rebase worktree on origin/main.

  6.  /spec-dev write <slug>        # spec before any code
      Implement → tests → fix until green.
      At each intermediate commit and whenever dirty > ~10 min:
        push claim-update (heartbeat + done-so-far + next) from main checkout
        rebase worktree on origin/main
      if tests unfixably red → claim status: blocked, leave worktree open, STOP

  7.  Update docs: feature spec, project-level spec, openapi if endpoints changed.

  8.  Bookkeeping commit (own commit, never bundled with feature code):
        git rm .work/active/<slug>.claim
        update "$SPRINT" according to the project AGENTS.md lifecycle
          (for example: delete the entry, or mark [x] — whatever the project uses)
        prepend entry to "$CHANGELOG"

  9.  Rebase worktree on origin/main if it moved → push → sync local main:
        git branch -f main origin/main

  10. Delete worktree + branch:
        git worktree remove --force <path>
        git branch -D <branch>
      Verify: git worktree list must not show the branch; test ! -d <path>

  11. # ── Report BEFORE next iteration ──
      "✓ <slug>: <one-line summary>"
      Name next recommended task + short reason.
      If session is long (multi-phase loop, >~50% context): suggest /compact.

  12. Go to 1
```

### Empty queue

When there are no unclaimed pending tasks — do not stop silently:

1. If project AGENTS.md gives an empty-queue example, follow it.
2. Read `$BACKLOG` — find top 3 most actionable items not yet in the queue.
3. Present each with a one-line rationale and rough effort.
4. Wait for the user's decision. **Do not add anything without explicit instruction** — priorities are the user's call.

### Recording tech debt

When you notice tech debt or a future improvement while working — record it immediately:

- Add an entry to `$BACKLOG` in the appropriate section.
- Optionally add a one-liner to `$SPRINT` if small and actionable.
- Include in the **same commit** as the work that surfaced it — never in a code comment.

Do NOT stop the current task to fix it.

---

## Task planning and tracking

These defaults apply when the project does not override them in `AGENTS.md`.
Configure file names via `SPRINT:`, `BACKLOG:`, `CHANGELOG:` keys (see §Configuration).
When `AGENTS.md` sets a lifecycle, the project-specific rule wins over the defaults below.

Three files, strict separation of concerns. In the default lifecycle, never
accumulate `[x]` done markers — move, don't mark.

### Files

**`$BACKLOG`** (default: `BACKLOG.md`) — long-term ideas and future milestones. Agents do not pick work from here directly.

```markdown
# Backlog

## <milestone or theme>
- [ ] <slug> — <short description>
```

Move items to `$SPRINT` when they are ready to be worked on. Delete promoted
items from `$BACKLOG` at that point (do not mark done).

---

**`$SPRINT`** (default: `SPRINT.md`) — short-term prioritized queue. This is what agents pick from.

```markdown
# Sprint

## Doing
- [ ] <slug> — <description>   ← claimed tasks (claim file is authoritative)

## Queue
- [ ] <slug> — <description>   ← highest priority first
- [ ] <slug> — <description>

## Backlog
(optional staging area for items about to be promoted from $BACKLOG)
```

When a task is complete in the default lifecycle: **delete** it from `$SPRINT`
and prepend it to `$CHANGELOG`. Do not leave `[x]` entries unless the project
AGENTS.md explicitly uses a check-off lifecycle.

---

**`$CHANGELOG`** (default: `CHANGELOG.md`) — append-only record of completed work. Newest first.

```markdown
# Changelog

## <slug> — <one-line summary>
Completed: <ISO date>
<optional 1-2 sentence description of what changed>

## <slug> — ...
```

---

### Promotion flow

```
$BACKLOG  →  $SPRINT  →  (claimed)  →  $CHANGELOG
  (idea)      (ready)       (doing)        (done)
```

- Items move **forward** through the pipeline; in the default lifecycle they are never marked done in-place.
- Only `$SPRINT` is read by agents during the autonomous loop — `$BACKLOG` is human-curated.
- The claim file in `.work/active/` is the authoritative source for "who is working on what right now."

---

## Coordination rules summary

- Claims are valid **only when visible on `origin/main`** — a local file or
  a commit on a feature branch is not a claim.
- Never assume a claim is yours because it exists — read `agent:` first.
- Heartbeat > 20 min = potentially orphaned; run `triage` before touching.
- Never `git reset --hard`, `git stash`, or `git restore .` on shared `main` —
  these destroy sibling agents' work.
- The absolute-path trap is the #1 source of lost work in worktree sessions.
