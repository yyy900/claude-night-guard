#!/usr/bin/env bash
# Install night-guard hooks into ~/.claude/settings.json.
# Usage: ./install.sh [preset]   (default: overnight-strict)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"
PRESET="${1:-overnight-strict}"
PRESET_FILE="$SCRIPT_DIR/presets/$PRESET.json"

if [[ ! -f "$PRESET_FILE" ]]; then
  echo "Unknown preset: $PRESET" >&2
  echo "Available:" >&2
  ls "$SCRIPT_DIR/presets" | sed 's/\.json$//' | sed 's/^/  /' >&2
  exit 1
fi

mkdir -p "$HOME/.claude" "$HOME/.claude/night-guard"

chmod +x "$SCRIPT_DIR"/hooks/pre/*.sh
chmod +x "$SCRIPT_DIR"/hooks/post/*.sh
chmod +x "$SCRIPT_DIR"/hooks/submit/*.sh
chmod +x "$SCRIPT_DIR/view-incidents.sh"

TMP_NEW=$(mktemp)
trap 'rm -f "$TMP_NEW"' EXIT
sed "s|__NG_ROOT__|$SCRIPT_DIR|g" "$PRESET_FILE" > "$TMP_NEW"

if [[ -s "$SETTINGS_FILE" ]]; then
  cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
  python3 - "$SETTINGS_FILE" "$TMP_NEW" <<'PYEOF'
import json, sys

existing_path, new_path = sys.argv[1], sys.argv[2]
with open(existing_path) as f:
    existing = json.load(f)
with open(new_path) as f:
    new = json.load(f)

def is_ng_entry(group):
    return any('claude-night-guard' in h.get('command', '') for h in group.get('hooks', []))

existing.setdefault('hooks', {})
for event, groups in new.get('hooks', {}).items():
    cur = existing['hooks'].setdefault(event, [])
    cur[:] = [g for g in cur if not is_ng_entry(g)]
    cur.extend(groups)

with open(existing_path, 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
PYEOF
  echo "Merged into $SETTINGS_FILE (backup: $SETTINGS_FILE.bak)"
else
  cp "$TMP_NEW" "$SETTINGS_FILE"
  echo "Created $SETTINGS_FILE"
fi

cat <<EOF

night-guard installed: preset=$PRESET
  hooks dir:    $SCRIPT_DIR/hooks
  incident log: $HOME/.claude/night-guard/incidents.jsonl
  view:         $SCRIPT_DIR/view-incidents.sh [since]

To uninstall, restore the backup or run: ./uninstall.sh
EOF
