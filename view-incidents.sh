#!/usr/bin/env bash
# View night-guard incidents. Usage: view-incidents.sh [since]
#   since: e.g. 24h, 7d, 30m   (default: 24h)
set -euo pipefail

NG_HOME="${NIGHT_GUARD_HOME:-$HOME/.claude/night-guard}"
LOG="$NG_HOME/incidents.jsonl"

if [[ ! -f "$LOG" ]]; then
  echo "No incidents yet ($LOG does not exist)"
  exit 0
fi

since="${1:-24h}"

python3 - "$LOG" "$since" <<'PYEOF'
import json, sys
from datetime import datetime, timezone, timedelta

log_path, since_spec = sys.argv[1], sys.argv[2]

def parse_since(spec):
    unit = spec[-1]
    num = int(spec[:-1])
    return timedelta(**{
        'h': {'hours': num},
        'd': {'days': num},
        'm': {'minutes': num},
    }[unit])

cutoff = datetime.now(timezone.utc) - parse_since(since_spec)

rows = []
with open(log_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
            ts = datetime.fromisoformat(d['ts'].replace('Z', '+00:00'))
            if ts >= cutoff:
                rows.append(d)
        except (json.JSONDecodeError, KeyError, ValueError):
            continue

if not rows:
    print(f"No incidents in the last {since_spec}.")
    sys.exit(0)

print(f"{len(rows)} incident(s) in the last {since_spec}:\n")
by_hook = {}
for inc in rows:
    by_hook.setdefault(inc['hook'], []).append(inc)

for hook in sorted(by_hook):
    items = by_hook[hook]
    print(f"[{hook}] x{len(items)}")
    for inc in items[:5]:
        cmd = (inc.get('command') or '').replace('\n', ' ')[:120]
        print(f"  {inc['ts']}  {cmd}")
        print(f"    reason: {inc.get('reason', '')}")
    if len(items) > 5:
        print(f"  ... and {len(items) - 5} more")
    print()
PYEOF
