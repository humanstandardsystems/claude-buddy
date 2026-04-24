#!/usr/bin/env bash
# install.sh — install claude-buddy into any project
# Usage: bash /path/to/claude-buddy/install.sh [target-dir]
# Defaults to current directory if no target is given.

set -euo pipefail

BUDDY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$(pwd)}"

# Don't install into the buddy repo itself
if [ "$TARGET" = "$BUDDY_DIR" ]; then
    echo "error: target cannot be the claude-buddy repo itself." >&2
    exit 1
fi

echo "Installing claude-buddy into: $TARGET"

# ── Create directory structure ───────────────────────────────────────────────
mkdir -p "$TARGET/.claude/hooks"
mkdir -p "$TARGET/.claude/commands"
mkdir -p "$TARGET/.claude/skills/done"
mkdir -p "$TARGET/Pets/species"

# ── Copy hook scripts ────────────────────────────────────────────────────────
cp "$BUDDY_DIR/.claude/hooks/_common.sh"       "$TARGET/.claude/hooks/"
cp "$BUDDY_DIR/.claude/hooks/pet-comment.sh"   "$TARGET/.claude/hooks/"
cp "$BUDDY_DIR/.claude/hooks/pet-name-react.sh" "$TARGET/.claude/hooks/"
cp "$BUDDY_DIR/.claude/hooks/pet-react.sh"     "$TARGET/.claude/hooks/"
chmod +x "$TARGET/.claude/hooks/"*.sh

# ── Copy slash commands ──────────────────────────────────────────────────────
cp "$BUDDY_DIR/.claude/commands/"*.md "$TARGET/.claude/commands/"

# ── Copy skills ──────────────────────────────────────────────────────────────
cp -r "$BUDDY_DIR/.claude/skills/done/." "$TARGET/.claude/skills/done/"

# ── Copy Python scripts ──────────────────────────────────────────────────────
cp "$BUDDY_DIR/.claude/statusline-pet.py" "$TARGET/.claude/"
cp "$BUDDY_DIR/.claude/rise.py"           "$TARGET/.claude/"

# ── Copy species templates ───────────────────────────────────────────────────
cp "$BUDDY_DIR/Pets/species/"*.md "$TARGET/Pets/species/"

# ── Copy inventory (skip if target already has one) ──────────────────────────
if [ ! -f "$TARGET/Pets/inventory.md" ]; then
    cp "$BUDDY_DIR/Pets/inventory.md" "$TARGET/Pets/"
fi

# ── Merge settings.json ───────────────────────────────────────────────────────
SETTINGS="$TARGET/.claude/settings.json"
STATUSLINE_CMD="python3 $TARGET/.claude/statusline-pet.py"

BUDDY_SETTINGS=$(cat <<JSON
{
  "statusLine": {
    "type": "command",
    "command": "$STATUSLINE_CMD",
    "refreshInterval": 1
  },
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/pet-name-react.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/pet-comment.sh"
          }
        ]
      }
    ]
  }
}
JSON
)

if [ -f "$SETTINGS" ]; then
    # Merge buddy config into existing settings.json
    python3 - "$SETTINGS" <<PY
import sys, json

with open(sys.argv[1]) as f:
    existing = json.load(f)

buddy = json.loads('''$BUDDY_SETTINGS''')

# Merge top-level keys (buddy values win for statusLine and hooks)
existing.update(buddy)

with open(sys.argv[1], 'w') as f:
    json.dump(existing, f, indent=2)

print("  merged into existing settings.json")
PY
else
    echo "$BUDDY_SETTINGS" > "$SETTINGS"
    echo "  created settings.json"
fi

echo ""
echo "Done. Next steps:"
echo "  1. Restart Claude Code in $TARGET"
echo "  2. Run /buddy to hatch your first pet"
