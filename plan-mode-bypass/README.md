# plan-mode-bypass

> Restores `bypassPermissions` mode after approving a plan in Claude Code.

## Problem

When you run Claude Code with `defaultMode: "bypassPermissions"` and use plan
mode (`opusplan` / Shift+Tab), approving the plan resets the session permission
mode back to `default` — every subsequent tool call shows a permission prompt
until you manually toggle bypass mode from the desktop.

## Solution

A `PreToolUse` hook returns `permissionDecision: "allow"` for every tool call,
bypassing the prompt regardless of the current session mode. `ExitPlanMode` is
excluded so the **Approve / Cancel** dialog still appears normally.

## Install

**Requirements:** `jq` (`brew install jq` on macOS)

```bash
# 1. Install the hook script (from the repo root)
./install.sh plan-mode-bypass
```

The installer copies the hook to `~/.claude/plugins/plan-mode-bypass/auto-allow.sh`
and prints the settings.json snippet to add.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "~/.claude/plugins/plan-mode-bypass/auto-allow.sh" }
        ]
      }
    ]
  }
}
```

Start a new Claude Code session. After approving the next plan, tool calls
will run without prompts.

## How it works

Claude Code fires `PreToolUse` before checking permissions. The hook reads
`tool_name` from stdin JSON and either:
- exits 0 with no output for `ExitPlanMode` → normal Approve/Cancel dialog
- prints `{"hookSpecificOutput":{"permissionDecision":"allow",...}}` → tool runs without prompt

The `defaultMode: "bypassPermissions"` in settings.json only sets the
startup default. When plan mode exits, it mutates the in-session mode directly
— `defaultMode` is not re-applied. The hook is the only reliable way to
intercept this.

## Files

- `hooks/auto-allow.sh` — the PreToolUse hook script
- `commands/plan-mode-bypass.md` — skill guide (installed by `install.sh`)
