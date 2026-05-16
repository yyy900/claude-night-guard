#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/feedback.sh"

ng_parse_input
[[ "$NG_TOOL_NAME" == "Bash" ]] || exit 0

cmd="$NG_BASH_COMMAND"
[[ "$cmd" == NIGHT_GUARD_ACK=force-push* ]] && exit 0

# Match git push with --force, --force-with-lease, -f, or +refspec.
if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+push\b.*(--force\b|--force-with-lease\b|[[:space:]]-f\b|[[:space:]]\+[a-zA-Z0-9_/.-]+:)'; then
  ng_block_and_log "block-force-push" "Bash" "$cmd" \
    "git push --force rewrites remote history; destroys others' work silently" \
    "Pull and rebase, or push to a new branch. --force-with-lease is safer but still gated overnight." \
    "NIGHT_GUARD_ACK=force-push <command>" \
    "$NG_SESSION_ID"
  exit 2
fi
exit 0
