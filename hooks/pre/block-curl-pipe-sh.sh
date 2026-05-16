#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/feedback.sh"

ng_parse_input
[[ "$NG_TOOL_NAME" == "Bash" ]] || exit 0

cmd="$NG_BASH_COMMAND"
[[ "$cmd" == NIGHT_GUARD_ACK=curl-pipe* ]] && exit 0

# curl/wget piped directly into a shell or interpreter.
if printf '%s' "$cmd" | grep -qE '\b(curl|wget|fetch)\b[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh|ksh|fish|python3?|node|ruby|perl|php)\b'; then
  ng_block_and_log "block-curl-pipe-sh" "Bash" "$cmd" \
    "curl/wget piped to a shell or interpreter — uninspected remote code execution" \
    "Download to a file, inspect it, then run. Or use the project's official installer/package." \
    "NIGHT_GUARD_ACK=curl-pipe <command>" \
    "$NG_SESSION_ID"
  exit 2
fi
exit 0
