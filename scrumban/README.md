# scrumban

Durable planning for crash-resilient autonomous work. The board (a few markdown
files in the repo), not your context, is the source of truth for what to do next —
so a reboot, a `/clear`, or a parallel agent can resume from it cold. Works with
**Claude Code** (`/scrumban`) and any agent that reads **AGENTS.md** (Codex, etc.).

## The one rule

**Write the plan into the board before you execute it.** If you want to do something,
queue it first (SPRINT for do-soon, BACKLOG for can-wait), *then* calmly do it. A
machine can reboot between "decide" and "finish"; unrecorded plans are orphaned work.

## What it provides

- **queue \<slug\>** — write a task into SPRINT/BACKLOG so a fresh agent can resume it
- **defer \<slug\>** — capture a follow-up / postponed edge case the instant you decide it
- **pick** — choose the next task from the board (not from memory)
- **done \<slug\>** — mark `[x]` with the outcome, changelog, spawned follow-ups
- **check** — "could a fresh agent resume from the board right now?" gate

Plus the anatomy of a resume-cold entry, and how it composes with `spec-dev`
(spec first) and `multi-agent` (claim/coordinate).

## Installation

### Option A — Claude Code plugin (recommended)

```bash
claude plugins marketplace add github:sergey-scherbina/agent-plugins
claude plugins install scrumban
```

Available as `/scrumban` in Claude Code.

### Option B — Direct install (works for all agents)

```bash
git clone https://github.com/sergey-scherbina/agent-plugins
cd agent-plugins
./install.sh scrumban
```

Copies `scrumban.md` to `~/.claude/commands/scrumban.md`.

### Connecting to a project (AGENTS.md)

Add to the project's `AGENTS.md` required-skills section:

```
Read ~/.claude/commands/scrumban.md for the durable-planning discipline
(write-before-do, SPRINT vs BACKLOG, resume-cold entries, queue follow-ups).
```

## Updating

```bash
# Claude Code
claude plugins update scrumban
# Any agent
git -C agent-plugins pull && ./install.sh scrumban
```
