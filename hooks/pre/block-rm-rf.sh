#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/feedback.sh"

ng_parse_input
[[ "$NG_TOOL_NAME" == "Bash" ]] || exit 0

cmd="$NG_BASH_COMMAND"

# Explicit override: agent prefixes with NIGHT_GUARD_ACK=rm-rf
[[ "$cmd" == NIGHT_GUARD_ACK=rm-rf* ]] && exit 0

# Match `rm` with -r and -f flags bundled together (any order, with other flag letters).
# Examples caught: rm -rf, rm -fr, rm -Rf, rm -rfv, rm -vRf
if printf '%s' "$cmd" | grep -qE '(^|[;&|`(]\s*|\s)rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[fF][a-zA-Z]*|-[a-zA-Z]*[fF][a-zA-Z]*[rR][a-zA-Z]*)([[:space:]]|$)'; then
  ng_block_and_log "block-rm-rf" "Bash" "$cmd" \
    "rm -rf is irreversible; strict overnight mode requires explicit ack" \
    "Confirm the target is safe (subdir under cwd, not /, ~, *, .), then re-run with prefix" \
    "NIGHT_GUARD_ACK=rm-rf <command>" \
    "$NG_SESSION_ID"
  exit 2
fi
exit 0
