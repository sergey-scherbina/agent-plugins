#!/usr/bin/env bash
# Install multi-agent skill to ~/.claude/commands/
# Works for Claude Code, Codex, and any other agent that reads AGENTS.md.
#
# Usage:
#   ./install.sh              # install all skills
#   ./install.sh multi-agent  # install specific skill

set -euo pipefail

DEST="$HOME/.claude/commands"
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
  echo "✓ installed $name → $DEST/$name.md"
}

if [ $# -eq 0 ]; then
  for dir in "$REPO_DIR"/*/; do
    name="$(basename "$dir")"
    [ -f "$dir/commands/$name.md" ] && install_skill "$name"
  done
else
  for name in "$@"; do
    install_skill "$name"
  done
fi

echo ""
echo "Add to your AGENTS.md:"
echo "  Read ~/.claude/commands/multi-agent.md for the multi-agent coordination protocol."
