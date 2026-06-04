# claude-plugins

Personal Claude Code plugin marketplace. Works with Claude Code and any
agent that reads AGENTS.md (Codex, etc.).

## Plugins

| Plugin | Description |
|---|---|
| [multi-agent](./multi-agent/) | Coordination protocol for parallel agents in feature branches |

## Installation

### For Claude Code

```bash
# Add as marketplace (once per machine)
claude plugins marketplace add github:sergey-scherbina/claude-plugins

# Install a plugin
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
Read ~/.claude/commands/multi-agent.md for the multi-agent coordination protocol.
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
