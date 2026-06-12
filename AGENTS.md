# agent-plugins — skill index for any agent

This repository is a bundle of **agent-independent skills** (plain markdown). A project
includes it as a git submodule at `.agents/plugins/`; its own `AGENTS.md` points one
line here. **No per-skill installation is needed** — any agent that reads this file
discovers every skill below and loads the relevant one on demand.

## How to use these skills (any agent)

1. **Convention:** every skill lives at `<name>/commands/<name>.md` (relative to this
   directory). Its first lines are YAML frontmatter (`description` = when to use it);
   the body is the agent-neutral instructions.
2. **Load on demand:** when a task matches a skill's *When to use* below, **read that
   skill's `commands/<name>.md`** (e.g. with your file/Read tool) and follow it. You do
   not need to copy or install anything.
3. **Discover new skills automatically:** this index may lag. The source of truth is the
   directory — **any subdirectory with a `commands/<name>.md` is a skill.** List
   `.agents/plugins/*/commands/*.md` to find skills added after this file was written.
4. **From a git worktree:** the submodule is only checked out in the shared main repo —
   do *not* `git submodule update --init` inside a worktree. Find the main repo and read
   skills from there:
   ```bash
   MAIN=$(git worktree list | head -1 | awk '{print $1}')
   # read: $MAIN/.agents/plugins/<name>/commands/<name>.md
   ```

## Skills

| Skill | When to use | Agent |
|---|---|---|
| [`scrumban`](./scrumban/commands/scrumban.md) | **Always.** Durable planning: write the plan into the board (`SPRINT.md`/`BACKLOG.md`) *before* executing, so a reboot/clear/parallel-agent resumes cold. Before starting, deferring, or finishing any task. | any |
| [`bugs`](./bugs/commands/bugs.md) | Any bug — reported in a room or found by you: track it in `BUGS.md` (status + repro + SHA + notes), work the fix loop, reproduce in the real harness, coordinate via `rozum`. | any |
| [`spec-dev`](./spec-dev/commands/spec-dev.md) | Every new feature or non-trivial change: write `specs/<slug>.md` first, commit it, implement against it, keep them in sync. | any |
| [`multi-agent`](./multi-agent/commands/multi-agent.md) | Parallel agents on a shared `origin/main`: claim a queued task, heartbeat, triage a foreign claim, release a stale claim, the worktree + autonomous-loop protocol. | any |
| [`multi-repo`](./multi-repo/commands/multi-repo.md) | Treating several repos as a virtual monorepo: status / sync / update-submodules / clone / run-in-each / register a repo. | any |
| [`rozum`](./rozum/commands/rozum.md) | Participating in a `rozum` meeting room (MCP): joining, posting, co-agent etiquette, `@name`/`@project` addressing, when to sweep the room. The default coordination channel. | any (needs rozum MCP) |
| [`plan-mode-bypass`](./plan-mode-bypass/commands/plan-mode-bypass.md) | Restore `bypassPermissions` after approving a plan. | Claude Code only (a hook) |

## Wiring a project to all of these

In the project's own `AGENTS.md`, one pointer is enough — **no per-skill setup**:

```
## Skills
Skills live in the `.agents/plugins/` submodule. Read `.agents/plugins/AGENTS.md`
(the index) and load any listed skill's `commands/<name>.md` on demand when its
*When to use* matches. New skills added to the submodule appear there automatically —
no project edit or installation. Update all skills with `git submodule update --remote`.
```

### Optional: Claude Code native slash-commands
The above (read-on-demand) is all that's required and works for every agent. Claude Code
users who *also* want native `/<name>` commands can install via the marketplace
(`.claude-plugin/marketplace.json` at this repo root):

```bash
claude plugins marketplace add github:sergey-scherbina/agent-plugins
claude plugins install scrumban      # or any listed skill
```

— but this is a convenience, not a requirement: even without it, the skill *works*
(the agent reads its `commands/<name>.md` when the trigger matches).
