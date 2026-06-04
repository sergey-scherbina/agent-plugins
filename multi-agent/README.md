# multi-agent

Coordination protocol for parallel agents working in feature branches on a
shared `origin/main`. Works with **Claude Code** (`/multi-agent`) and any
agent that reads **AGENTS.md** (Codex, etc.).

## What it provides

- **status** — active claims, heartbeat ages, pending tasks, stale claims
- **claim \<slug\>** — claim a task with agent identity + heartbeat
- **triage \<slug\>** — assess a foreign claim; decide to continue, abandon, or skip
- **heartbeat** — refresh liveness signal on your active claim
- **release \<slug\>** — free an abandoned claim

Plus the full reference: claim file format, worktree workflow, autonomous loop.

## Installation

### Option A — Claude Code plugin (recommended for Claude Code users)

```bash
# Add this repo as a marketplace (once per machine)
claude plugins marketplace add github:sergey-scherbina/agent-plugins

# Install the plugin
claude plugins install multi-agent
```

The skill is now available as `/multi-agent` in Claude Code.

For cross-agent use (Codex, etc.) also run `install.sh` — see Option B.

### Option B — Direct install (works for all agents)

```bash
git clone https://github.com/sergey-scherbina/agent-plugins
cd agent-plugins
./install.sh multi-agent
```

This copies `multi-agent.md` to `~/.claude/commands/multi-agent.md`.

### Connecting to a project (AGENTS.md)

Add one line to the project's `AGENTS.md` coordination section:

```
Read ~/.claude/commands/multi-agent.md for the multi-agent coordination protocol
(claim format, agent identity, heartbeat, triage, worktree workflow, loop).
```

Both Claude Code and Codex will read the file from that stable path.

## Updating

```bash
# Claude Code
claude plugins update multi-agent

# Any agent
git -C agent-plugins pull && ./install.sh multi-agent
```
