#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/feedback.sh"

ng_parse_input
[[ "$NG_TOOL_NAME" == "Bash" ]] || exit 0

cmd="$NG_BASH_COMMAND"
printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+commit\b' || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

diff=$(git show --no-color HEAD 2>/dev/null || true)
[[ -z "$diff" ]] && exit 0

# Secret patterns — high-signal only, to keep false positives low.
patterns=(
  'AKIA[0-9A-Z]{16}'
  'aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{20,}'
  '-----BEGIN (RSA |OPENSSH |EC |DSA |PGP )?PRIVATE KEY-----'
  'sk-(ant-)?[a-zA-Z0-9_-]{32,}'
  'ghp_[a-zA-Z0-9]{36}'
  'gho_[a-zA-Z0-9]{36}'
  'github_pat_[a-zA-Z0-9_]{82}'
  'xox[baprs]-[0-9]+-[0-9]+-[a-zA-Z0-9]+'
  'AIza[0-9A-Za-z_-]{35}'
)

matched=""
for p in "${patterns[@]}"; do
  if printf '%s' "$diff" | grep -qE "$p"; then
    matched="$p"
    break
  fi
done

[[ -z "$matched" ]] && exit 0

ng_log_incident "audit-commit-secrets" "Bash" "$cmd" \
  "POST-COMMIT secret pattern in HEAD: $matched (not auto-reverted)" \
  "$NG_SESSION_ID"
ng_bump_counter "$NG_SESSION_ID" "audit-commit-secrets"

cat >&2 <<EOF
[NIGHT-GUARD AUDIT] HEAD commit may contain a credential matching: $matched

This was a POST hook — the commit already exists locally. NOT auto-reverted because rollback is itself destructive.

Required actions:
  1. STOP. Do not push.
  2. Verify it is a real secret (not a fixture / dummy).
  3. If real: rotate the credential immediately — assume compromised.
  4. Then: git reset --soft HEAD~1, remove the secret, recommit.

Report to the user before doing anything else.
EOF
exit 0
