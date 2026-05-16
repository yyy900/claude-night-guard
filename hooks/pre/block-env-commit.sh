#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/feedback.sh"

ng_parse_input

is_secret_path() {
  case "$1" in
    *.env|*.env.*|.env|.env.*) return 0 ;;
    *credentials.json|*credentials.yaml|*credentials.yml) return 0 ;;
    *.pem|*.key|*.p12|*.pfx) return 0 ;;
    *id_rsa|*id_ed25519|*id_ecdsa|*id_dsa) return 0 ;;
    */secrets/*|*/.secrets/*) return 0 ;;
  esac
  return 1
}

# Bash: catch `git add` / `cp` / `mv` of secret-pattern files
if [[ "$NG_TOOL_NAME" == "Bash" ]]; then
  cmd="$NG_BASH_COMMAND"
  [[ "$cmd" == NIGHT_GUARD_ACK=env-commit* ]] && exit 0

  if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+add\b' && \
     printf '%s' "$cmd" | grep -qE '(\.env(\.|\b)|credentials\.(json|ya?ml)|\.pem\b|\.key\b|id_(rsa|ed25519|ecdsa|dsa)\b|/secrets?/)'; then
    ng_block_and_log "block-env-commit" "Bash" "$cmd" \
      "git add target matches secret-file pattern" \
      "Add to .gitignore. If the file is intentionally tracked (e.g. .env.example), verify no real secrets, then ack." \
      "NIGHT_GUARD_ACK=env-commit <command>" \
      "$NG_SESSION_ID"
    exit 2
  fi
fi

# Edit / Write: block writes to secret-pattern file paths
if [[ "$NG_TOOL_NAME" == "Write" || "$NG_TOOL_NAME" == "Edit" ]]; then
  path="$NG_EDIT_FILE_PATH"
  if [[ -n "$path" ]] && is_secret_path "$path"; then
    ng_block_and_log "block-env-commit" "$NG_TOOL_NAME" "$path" \
      "writing to a secret-pattern file path ($path)" \
      "Edit via a secrets manager (1Password, vault, etc) or have the user do it manually" \
      "No automated override — user must edit directly" \
      "$NG_SESSION_ID"
    exit 2
  fi
fi
exit 0
