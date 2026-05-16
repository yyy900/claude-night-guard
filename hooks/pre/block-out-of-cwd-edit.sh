#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/feedback.sh"

ng_parse_input
[[ "$NG_TOOL_NAME" == "Write" || "$NG_TOOL_NAME" == "Edit" ]] || exit 0

path="$NG_EDIT_FILE_PATH"
[[ -z "$path" ]] && exit 0

case "$path" in
  /*) abs="$path" ;;
  *)  abs="$PWD/$path" ;;
esac

# Resolve symlinks / .. components if realpath is available.
if command -v realpath >/dev/null 2>&1; then
  # Use -m to allow non-existent paths (Write creates them).
  resolved=$(realpath -m "$abs" 2>/dev/null || echo "$abs")
else
  resolved="$abs"
fi

# Allow: under cwd, /tmp, $TMPDIR, $HOME/.claude.
# Extra allowed prefixes via NIGHT_GUARD_ALLOW_PATHS (colon-separated).
allowed=("$PWD" "/tmp" "${TMPDIR:-/tmp}" "$HOME/.claude")
if [[ -n "${NIGHT_GUARD_ALLOW_PATHS:-}" ]]; then
  IFS=':' read -ra extra <<< "$NIGHT_GUARD_ALLOW_PATHS"
  allowed+=("${extra[@]}")
fi

for prefix in "${allowed[@]}"; do
  [[ -z "$prefix" ]] && continue
  if [[ "$resolved" == "$prefix" || "$resolved" == "$prefix"/* ]]; then
    exit 0
  fi
done

ng_block_and_log "block-out-of-cwd-edit" "$NG_TOOL_NAME" "$path" \
  "edit target ($resolved) is outside cwd ($PWD) and allowed prefixes" \
  "Operate from the correct project root, or extend NIGHT_GUARD_ALLOW_PATHS if this is legitimate" \
  "Set env NIGHT_GUARD_ALLOW_PATHS=/extra/prefix to widen scope" \
  "$NG_SESSION_ID"
exit 2
