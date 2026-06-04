#!/bin/bash
# PreToolUse hook: auto-approve all tool calls except ExitPlanMode.
# This restores bypass-permissions behavior after plan approval.
# ExitPlanMode is excluded so the Approve/Cancel dialog still appears.
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
if [ "$tool_name" = "ExitPlanMode" ]; then
  exit 0
fi
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"plan-mode-bypass: restoring bypassPermissions after plan approval"}}\n'
