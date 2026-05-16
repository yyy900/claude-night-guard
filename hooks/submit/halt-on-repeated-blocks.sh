#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/feedback.sh"

ng_parse_input

threshold="${NIGHT_GUARD_HALT_THRESHOLD:-3}"
session="$NG_SESSION_ID"
[[ -z "$session" ]] && exit 0

total=0
breakdown=""
shopt -s nullglob
for f in "$NG_COUNTER_DIR"/${session}__*.count; do
  count=$(cat "$f")
  hook=$(basename "$f" .count | sed "s/^${session}__//")
  total=$((total + count))
  breakdown+="  - $hook: $count"$'\n'
done
shopt -u nullglob

(( total < threshold )) && exit 0

# Stdout from UserPromptSubmit is injected as additional context for this turn.
cat <<EOF
[NIGHT-GUARD HALT] This session has triggered $total safety blocks (threshold: $threshold).

Breakdown:
$breakdown
This usually means you are repeatedly attempting a dangerous operation that needs human review. Do NOT continue automated work.

Required response this turn:
  1. State what you were trying to do.
  2. State why each block fired (read the BLOCKED stderr from prior tool results).
  3. State what specific decision the user needs to make.
  4. Stop. Wait for explicit user direction before any further tool use.

Do not attempt overrides (NIGHT_GUARD_ACK=...) unless the user explicitly authorizes one in their next message.
EOF
exit 0
