# agent-plugins

Personal agent skill collection. Works with Claude Code and any agent that
reads AGENTS.md (Codex, etc.).

## Skills

| Skill | Description |
|---|---|
| [multi-agent](./multi-agent/) | Coordination protocol for parallel agents in feature branches |
| [multi-repo](./multi-repo/) | Workspace management for repositories listed in `REPOS.md` |
| [spec-dev](./spec-dev/) | Spec-driven development workflow: write, implement, verify |

## Installation

### For Claude Code

```bash
# Add as marketplace (once per machine)
claude plugins marketplace add github:sergey-scherbina/claude-plugins

# Install a plugin-backed skill
claude plugins install multi-agent
```

### For any agent (Codex, etc.)

```bash
git clone https://github.com/sergey-scherbina/claude-plugins
cd claude-plugins
./install.sh              # installs all plugins
./install.sh multi-agent  # installs one plugin
```

Files are copied to `~/.claude/commands/`. Reference from `AGENTS.md`:

```
Read ~/.claude/commands/<skill>.md for the relevant protocol.
```

## Adding a new plugin

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json       ← name, version, description, author
├── commands/
│   └── my-plugin.md      ← AGENTS.md-compatible skill (no tool-specific frontmatter)
└── README.md
```

The `install.sh` auto-discovers any plugin that has `commands/<name>.md`.
