#!/usr/bin/env bash
# Remove night-guard hooks from ~/.claude/settings.json.
# Leaves the incident log and counters intact.
set -euo pipefail

SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo "$SETTINGS_FILE does not exist — nothing to do."
  exit 0
fi

cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
python3 - "$SETTINGS_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)

def is_ng_entry(group):
    return any('claude-night-guard' in h.get('command', '') for h in group.get('hooks', []))

for event, groups in list(d.get('hooks', {}).items()):
    kept = [g for g in groups if not is_ng_entry(g)]
    if kept:
        d['hooks'][event] = kept
    else:
        del d['hooks'][event]
if not d.get('hooks'):
    d.pop('hooks', None)

with open(path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
PYEOF
echo "Removed night-guard entries from $SETTINGS_FILE (backup: $SETTINGS_FILE.bak)"
