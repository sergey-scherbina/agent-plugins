# bugs

Durable bug handling. A bug must not live only in chat or only in your head — it goes
into a repo file, **`BUGS.md`**, so it survives a reboot/`/clear` and every collaborator
can see its status. The ledger records; a meeting room (rozum) coordinates. Works with
**Claude Code** (`/bugs`) and any agent that reads **AGENTS.md** (Codex, etc.).

## The one rule

**Track every reported or discovered bug in `BUGS.md`, and work the fix loop from the
repo — not from memory.** Status flows `open → needs-info → fixed → done`; an entry
closes only when the reporter confirms.

## What it provides

- **The `BUGS.md` ledger** — one entry per bug: status, reporter, how to reproduce,
  root cause, fix SHA, open questions.
- **The per-iteration loop** — sweep the room when no other task is in flight; record /
  ask / fix / report / confirm-and-close.
- **The fix loop** — `working:` ack → record in `BUGS.md` + board/spec → reproduce in
  the **real harness** (not a dev-only runner) → fix + a regression test that mirrors
  the reporter's repro shape (multi-file for cross-module) → `done:` with SHA + honest
  root cause.

Composes with `scrumban` (queue the fix before coding), `rozum` (coordinate / address
with `@name`/`@project`), and `multi-agent` (claim before working).

## Installation

### Option A — Claude Code plugin (recommended)

```bash
claude plugins marketplace add github:sergey-scherbina/agent-plugins
claude plugins install bugs
```

Available as `/bugs` in Claude Code.

### Option B — Direct install (works for all agents)

```bash
git clone https://github.com/sergey-scherbina/agent-plugins
cd agent-plugins
./install.sh bugs
```

Copies `bugs.md` to `~/.claude/commands/bugs.md`.

### Connecting to a project (AGENTS.md)

Add to the project's `AGENTS.md` required-skills section:

```
Read .agents/plugins/bugs/commands/bugs.md for bug handling
(BUGS.md ledger + fix loop, reproduce in the real harness, coordinate via rozum).
```

## Updating

```bash
# Claude Code
claude plugins update bugs
# Any agent
git -C agent-plugins pull && ./install.sh bugs
```
