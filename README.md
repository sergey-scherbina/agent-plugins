# agent-plugins

Agent skill collection for parallel multi-branch development workflows.
Compatible with Claude Code (`/skill-name`) and any agent that reads plain
Markdown (Codex, GPT, etc.).

**Zero-install usage:** add this repo as a submodule and point your project's
`AGENTS.md` at [`AGENTS.md`](./AGENTS.md) (the skill index). Any agent then discovers
and loads every skill on demand — no per-skill install, and future skills appear
automatically. The Claude Code marketplace below is an optional native-command layer.

## Skills

| Skill | Description |
|---|---|
| [scrumban](./scrumban/) | Durable planning: write-before-do, SPRINT vs BACKLOG, resume-cold entries, queue follow-ups — so a reboot/`/clear`/parallel agent resumes from the board cold |
| [bugs](./bugs/) | Durable bug handling: a `BUGS.md` ledger (status/repro/SHA/notes) + a fix loop (reproduce in the real harness, faithful regression test), coordinated via rozum |
| [multi-agent](./multi-agent/) | Coordination protocol for parallel agents: claim/heartbeat/triage/release + autonomous loop |
| [multi-repo](./multi-repo/) | Workspace management for repos listed in `REPOS.md`: status, sync, update, clone |
| [spec-dev](./spec-dev/) | Spec-driven development: write spec → implement → verify, keep spec in sync |
| [plan-mode-bypass](./plan-mode-bypass/) | Restore `bypassPermissions` after approving a plan in Claude Code plan mode |

## Usage

### Option A — as a git submodule (recommended for projects)

```bash
# Add once to your project
git submodule add https://github.com/sergey-scherbina/agent-plugins .agents/plugins
git submodule update --init .agents/plugins
```

Submodules are only initialized in the **shared main checkout**.
Worktrees do not need their own submodule init. From any worktree, read
skills via the main repo root:

```bash
MAIN=$(git worktree list | head -1 | awk '{print $1}')
# read: $MAIN/.agents/plugins/<skill>/commands/<skill>.md
```

Reference this in `AGENTS.md`:

```markdown
Skill files: `$MAIN/.agents/plugins/<skill>/commands/<skill>.md`
where MAIN=$(git worktree list | head -1 | awk '{print $1}')
```

### Option B — install to `~/.claude/commands/`

```bash
git clone https://github.com/sergey-scherbina/agent-plugins
cd agent-plugins
./install.sh              # all skills
./install.sh multi-agent  # one skill
```

Files land in `~/.claude/commands/<skill>.md`. Works for Claude Code slash
commands and any agent that resolves `~/.claude/commands/`.

### Option C — Claude Code plugin marketplace

```bash
claude plugins marketplace add github:sergey-scherbina/agent-plugins
claude plugins install multi-agent
```

## Updating

```bash
# Submodule
git submodule update --remote .agents/plugins

# Installed copy
git -C agent-plugins pull && ./install.sh

# Claude Code marketplace
claude plugins update multi-agent
```

## Adding a new plugin

```
my-plugin/
├── commands/
│   └── my-plugin.md      # skill definition — plain Markdown, no tool-specific frontmatter
├── hooks/                # optional: shell scripts for Claude Code hooks
│   └── auto-allow.sh
└── README.md
```

`install.sh` auto-discovers any directory that has `commands/<name>.md`.
