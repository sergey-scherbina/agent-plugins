# plan-mode-bypass

Restores `bypassPermissions` mode after approving a plan in Claude Code plan mode.

## Problem

Claude Code's plan mode (`opusplan` / Shift+Tab) temporarily switches the session
to a read-only mode. When you click **Approve**, the plan mode exits — but the
session permission mode drops back to `default` (ask-permissions), not to
`bypassPermissions`. Every subsequent tool call shows a permission prompt until
you manually toggle bypass mode back from the desktop.

## Solution

A `PreToolUse` hook intercepts every tool call before the permission check and
returns `permissionDecision: "allow"` — bypassing the prompt regardless of session
mode. `ExitPlanMode` is explicitly excluded so the **Approve / Cancel** dialog
still appears as normal.

## Install

**Via `install.sh`** (recommended):

```bash
./install.sh plan-mode-bypass
```

This copies the hook script to `~/.claude/plugins/plan-mode-bypass/auto-allow.sh`
and prints the settings.json snippet to add.

**Manual:**

```bash
cp hooks/auto-allow.sh ~/.claude/plugins/plan-mode-bypass/auto-allow.sh
chmod +x ~/.claude/plugins/plan-mode-bypass/auto-allow.sh
```

Then add to `~/.claude/settings.json` under `"hooks"`:

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/plugins/plan-mode-bypass/auto-allow.sh"
        }
      ]
    }
  ]
}
```

3. Start a new Claude Code session.

## Verify

After approving a plan, Claude should run `Bash`, `Edit`, `Read` and other tools
without any permission prompts.

To test the script directly:

```bash
echo '{"tool_name":"Read"}' | ~/.claude/auto-allow.sh
# → {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow",...}}

echo '{"tool_name":"ExitPlanMode"}' | ~/.claude/auto-allow.sh
# → (no output, exit 0 — plan dialog shows normally)
```

## Requirements

- `jq` must be installed (`brew install jq` on macOS)
- Claude Code with hooks support
