#!/usr/bin/env bash
# Install agent skills and hooks to ~/.claude/
# Works for Claude Code, Codex, and any other agent that reads AGENTS.md.
#
# Usage:
#   ./install.sh              # install all plugins
#   ./install.sh multi-agent  # install specific plugin

set -euo pipefail

DEST="$HOME/.claude/commands"
HOOKS_DEST="$HOME/.claude/plugins"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

install_skill() {
  local name="$1"
  local src="$REPO_DIR/$name/commands/$name.md"
  if [ ! -f "$src" ]; then
    echo "ERROR: $src not found" >&2
    return 1
  fi
  mkdir -p "$DEST"
  cp "$src" "$DEST/$name.md"
  echo "✓ installed $name skill → $DEST/$name.md"
}

install_hooks() {
  local name="$1"
  local hooks_dir="$REPO_DIR/$name/hooks"
  [ -d "$hooks_dir" ] || return 0
  local dest="$HOOKS_DEST/$name"
  mkdir -p "$dest"
  for script in "$hooks_dir"/*.sh; do
    [ -f "$script" ] || continue
    cp "$script" "$dest/"
    chmod +x "$dest/$(basename "$script")"
    echo "✓ installed $name hook → $dest/$(basename "$script")"
  done
  echo ""
  echo "  ── $name: add to ~/.claude/settings.json ──────────────────"
  printf '  "hooks": {\n    "PreToolUse": [\n      {\n        "matcher": "*",\n        "hooks": [\n          { "type": "command", "command": "%s/%s/auto-allow.sh" }\n        ]\n      }\n    ]\n  }\n' "$HOOKS_DEST" "$name"
  echo "  ────────────────────────────────────────────────────────────"
  echo ""
}

install_plugin() {
  local name="$1"
  [ -f "$REPO_DIR/$name/commands/$name.md" ] && install_skill "$name"
  install_hooks "$name"
}

if [ $# -eq 0 ]; then
  for dir in "$REPO_DIR"/*/; do
    name="$(basename "$dir")"
    install_plugin "$name"
  done
else
  for name in "$@"; do
    install_plugin "$name"
  done
fi

echo ""
echo "Add to your AGENTS.md:"
echo "  Read ~/.claude/commands/<skill>.md for the relevant protocol."
