---
description: "Multi-repo workspace management. Treats a set of repositories as a virtual monorepo. Use when checking status across repos, syncing all repos, updating submodules to remote heads, cloning a workspace from scratch, running a command in every repo, or registering a new repo."
argument-hint: "status | sync | update | clone | foreach <cmd> | add <alias> <url> [path]"
---

# Multi-repo workspace

Manages a set of repositories as a virtual monorepo. The registry lives in
`REPOS.md`; optional per-repo detail files live in `repos/`.

**Action dispatch:**

| Task | Section |
|---|---|
| Show status of all repos | [→ status](#status) |
| Fetch, pull, update pinned submodules in all repos | [→ sync](#sync) |
| Fetch, pull, advance submodules to remote heads | [→ update](#update) |
| Clone missing repos from registry | [→ clone](#clone) |
| Run a shell command in every repo | [→ foreach-cmd](#foreach-cmd) |
| Register a new repo | [→ add-alias-url-path](#add-alias-url-path) |

---

## Registry format

**`REPOS.md`** — one entry per repo:

```markdown
# Repositories

## <alias>
url: <git-url>
path: <local-path>     # relative to the directory containing REPOS.md
branch: main           # optional, default: main
submodules: true       # optional: sync pinned submodules; update advances to remote heads
```

**`repos/<alias>.md`** — optional per-repo detail file. Free-form markdown:
purpose, build commands, test commands, dependencies, gotchas. Agents read this
when they need context about a specific repo.

### Reading the registry

```bash
REGISTRY="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/REPOS.md"
# Parse each ## <alias> block: read url:, path:, branch:, submodules: fields
```

Canonical parser (works from any context):
```bash
parse_repos() {
  local file="$1"
  local alias url path branch submodules
  while IFS= read -r line; do
    case "$line" in
      "## "*)  alias="${line#'## '}" ; url="" ; path="" ; branch="main" ; submodules="false" ;;
      "url: "*) url="${line#'url: '}" ;;
      "path: "*) path="${line#'path: '}" ;;
      "branch: "*) branch="${line#'branch: '}" ;;
      "submodules: true") submodules="true" ;;
      "") [ -n "$alias" ] && [ -n "$url" ] && echo "$alias|$url|$path|$branch|$submodules" ;;
    esac
  done < "$file"
  [ -n "$alias" ] && [ -n "$url" ] && echo "$alias|$url|$path|$branch|$submodules"
}
```

---

## Actions

### status

Show current state of every registered repo.

```bash
ROOT="$(dirname "$REGISTRY")"
parse_repos "$REGISTRY" | while IFS='|' read -r alias url path branch submodules; do
  REPO="$ROOT/$path"
  if [ ! -d "$REPO/.git" ] && [ ! -f "$REPO/.git" ]; then
    printf "  %-20s  NOT CLONED\n" "$alias"
    continue
  fi
  cd "$REPO"
  git fetch origin --quiet 2>/dev/null
  current=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
  dirty=$(git status --porcelain | wc -l | tr -d ' ')
  ahead=$(git rev-list --count "origin/$current..HEAD" 2>/dev/null || echo "?")
  behind=$(git rev-list --count "HEAD..origin/$current" 2>/dev/null || echo "?")
  dirty_str=$([ "$dirty" -gt 0 ] && echo " dirty:$dirty" || echo "")
  ahead_str=$([ "$ahead" != "0" ] && [ "$ahead" != "?" ] && echo " ↑$ahead" || echo "")
  behind_str=$([ "$behind" != "0" ] && [ "$behind" != "?" ] && echo " ↓$behind" || echo "")
  printf "  %-20s  %-15s%s%s%s\n" "$alias" "$current" "$dirty_str" "$ahead_str" "$behind_str"
done
```

Print format:
```
  scalascript           main             dirty:2 ↑1
  busi                  main
  agent-plugins         main                     ↓3
```

---

### sync

Fetch + fast-forward pull + pinned submodule update in every registered repo.
This keeps the working tree at the commits recorded by the superproject. It
does not advance submodules to their remote heads.

```bash
ROOT="$(dirname "$REGISTRY")"
parse_repos "$REGISTRY" | while IFS='|' read -r alias url path branch submodules; do
  REPO="$ROOT/$path"
  if [ ! -d "$REPO/.git" ] && [ ! -f "$REPO/.git" ]; then
    echo "  $alias: NOT CLONED — run /multi-repo clone first"
    continue
  fi
  echo "  syncing $alias..."
  cd "$REPO"
  git fetch origin
  # Fast-forward only — never merge/rebase dirty working trees
  if git diff --quiet && git diff --cached --quiet; then
    git merge --ff-only "origin/$branch" 2>/dev/null \
      && echo "    ✓ up to date" \
      || echo "    ⚠ cannot fast-forward (dirty or diverged) — skipped"
  else
    echo "    ⚠ dirty working tree — fetch only, skipped pull"
  fi
  if [ "$submodules" = "true" ]; then
    echo "    updating submodules..."
    git submodule update --init --recursive
    echo "    ✓ submodules updated"
  fi
done
```

---

### update

Fetch + fast-forward pull + remote submodule update in every registered repo.
This intentionally advances submodules to the branch heads configured in
`.gitmodules` by running `git submodule update --init --remote --recursive`.

Use this when you want the workspace to consume the latest submodule commits.
If a superproject records submodule pointers, this may leave that superproject
dirty; commit the pointer bump from a normal feature worktree after testing.

```bash
ROOT="$(dirname "$REGISTRY")"
parse_repos "$REGISTRY" | while IFS='|' read -r alias url path branch submodules; do
  REPO="$ROOT/$path"
  if [ ! -d "$REPO/.git" ] && [ ! -f "$REPO/.git" ]; then
    echo "  $alias: NOT CLONED — run /multi-repo clone first"
    continue
  fi
  echo "  updating $alias..."
  cd "$REPO"
  git fetch origin
  # Fast-forward only — never merge/rebase dirty working trees
  if git diff --quiet && git diff --cached --quiet; then
    git merge --ff-only "origin/$branch" 2>/dev/null \
      && echo "    ✓ up to date" \
      || echo "    ⚠ cannot fast-forward (dirty or diverged) — skipped"
  else
    echo "    ⚠ dirty working tree — fetch only, skipped pull"
  fi
  if [ "$submodules" = "true" ]; then
    echo "    updating submodules to remote heads..."
    git submodule update --init --remote --recursive
    echo "    ✓ submodules updated to remote heads"
  fi
done
```

---

### clone

Clone all repos listed in `REPOS.md` that do not yet exist locally. Initializes
submodules for repos with `submodules: true`.

```bash
ROOT="$(dirname "$REGISTRY")"
parse_repos "$REGISTRY" | while IFS='|' read -r alias url path branch submodules; do
  REPO="$ROOT/$path"
  if [ -d "$REPO/.git" ] || [ -f "$REPO/.git" ]; then
    echo "  $alias: already exists — skipping"
    continue
  fi
  echo "  cloning $alias → $path..."
  git clone --branch "$branch" "$url" "$REPO"
  if [ "$submodules" = "true" ]; then
    echo "    initializing submodules..."
    git -C "$REPO" submodule update --init --recursive
  fi
  echo "  ✓ $alias"
done
```

---

### foreach `<cmd>`

Run a shell command in every repo that exists locally. Prints output grouped by alias.

```bash
CMD="<cmd>"   # the command to run
ROOT="$(dirname "$REGISTRY")"
parse_repos "$REGISTRY" | while IFS='|' read -r alias url path branch submodules; do
  REPO="$ROOT/$path"
  [ -d "$REPO/.git" ] || [ -f "$REPO/.git" ] || continue
  echo "=== $alias ==="
  (cd "$REPO" && eval "$CMD")
  echo ""
done
```

Example: `/multi-repo foreach "git log --oneline -3"`

---

### add `<alias>` `<url>` `[path]`

Register a new repo in `REPOS.md`.

```bash
ALIAS="<alias>"
URL="<url>"
PATH_VAL="${3:-../$ALIAS}"    # default: sibling directory named after alias

# Append to REPOS.md
cat >> "$REGISTRY" <<EOF

## $ALIAS
url: $URL
path: $PATH_VAL
branch: main
EOF

echo "Added $ALIAS to REPOS.md"
echo "Run /multi-repo clone to fetch it, or /multi-repo status to check."
```

Optionally create a stub detail file:
```bash
mkdir -p "$(dirname "$REGISTRY")/repos"
cat > "$(dirname "$REGISTRY")/repos/$ALIAS.md" <<EOF
# $ALIAS

url: $URL

## Overview
<!-- Describe what this repo is and how it relates to the workspace -->

## Build
<!-- How to build / run -->

## Dependencies
<!-- What this repo depends on -->
EOF
echo "Created repos/$ALIAS.md — fill in the details."
```

---

## Workspace layout

```
<workspace-root>/
  REPOS.md            ← registry (required)
  repos/              ← per-repo detail files (optional)
    scalascript.md
    busi.md
    agent-plugins.md
```

`REPOS.md` can live anywhere — the skill resolves all `path:` values relative
to the directory containing `REPOS.md`. A typical layout puts it at the
workspace root alongside sibling repo directories:

```
workspace/
  REPOS.md
  scalascript/    ← path: ../scalascript  (or ./scalascript if nested)
  busi/
  agent-plugins/
```

---

## Submodule management

When `submodules: true` is set for a repo, the skill runs
`git submodule update --init --recursive` after every pull (sync) and after
cloning. This initializes submodules and checks out the commits pinned by the
superproject.

Use `/multi-repo update` when you intentionally want
`git submodule update --init --remote --recursive`. After testing, commit any
resulting superproject pointer bump as a normal project change.

To sync only one repo's pinned submodules manually:

```bash
cd "$ROOT/$path"
git submodule update --init --recursive
```

To advance only one repo's submodules to remote heads manually:

```bash
cd "$ROOT/$path"
git submodule update --init --remote --recursive
```

---

## Integration with multi-agent

When multiple agents work across repos in parallel, each agent still follows
the single-repo worktree protocol (one worktree per task, claim on `origin/main`).
The multi-repo skill is read-only from the coordination perspective — it does
not replace claiming or heartbeat protocols.

Typical multi-agent + multi-repo flow:
1. Agent reads `REPOS.md` to understand the workspace layout.
2. Agent checks `repos/<alias>.md` for the repo it will work in.
3. Agent creates a worktree in that repo and claims the task (per `/multi-agent`).
4. After finishing, agent runs `/multi-repo sync` to propagate pinned changes
   across the workspace, or `/multi-repo update` when intentionally advancing
   submodules to remote heads.
