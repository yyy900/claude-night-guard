#!/usr/bin/env bash
# night-guard shared library: input parsing, blocking, incident logging, counters.
# Sourced by every hook. Stdin must be the Claude Code hook JSON payload.

NG_HOME="${NIGHT_GUARD_HOME:-$HOME/.claude/night-guard}"
NG_LOG="$NG_HOME/incidents.jsonl"
NG_COUNTER_DIR="$NG_HOME/counters"
mkdir -p "$NG_HOME" "$NG_COUNTER_DIR"

ng_parse_input() {
  local input
  input=$(cat)
  NG_INPUT_JSON="$input"
  eval "$(printf '%s' "$input" | python3 -c "
import json, sys, shlex
d = json.load(sys.stdin)
ti = d.get('tool_input', {}) or {}
out = {
  'NG_TOOL_NAME':     d.get('tool_name', ''),
  'NG_SESSION_ID':    d.get('session_id', ''),
  'NG_HOOK_EVENT':    d.get('hook_event_name', ''),
  'NG_BASH_COMMAND':  ti.get('command', ''),
  'NG_EDIT_FILE_PATH': ti.get('file_path', ''),
  'NG_USER_PROMPT':   d.get('prompt', ''),
}
for k, v in out.items():
    print(f'{k}={shlex.quote(str(v))}')
")"
}

ng_log_incident() {
  local hook="$1" tool="$2" command="$3" reason="$4" session="$5"
  local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  python3 -c "
import json, sys
print(json.dumps({
  'ts':       sys.argv[1],
  'hook':     sys.argv[2],
  'tool':     sys.argv[3],
  'command':  sys.argv[4],
  'reason':   sys.argv[5],
  'session':  sys.argv[6],
}))" "$ts" "$hook" "$tool" "$command" "$reason" "$session" >> "$NG_LOG"
}

ng_bump_counter() {
  local session="$1" hook="$2"
  local file="$NG_COUNTER_DIR/${session}__${hook}.count"
  local count=0
  [[ -f "$file" ]] && count=$(cat "$file")
  count=$((count + 1))
  echo "$count" > "$file"
}

ng_block_and_log() {
  local hook="$1" tool="$2" command="$3" reason="$4" suggestion="$5" override="$6" session="$7"
  ng_log_incident "$hook" "$tool" "$command" "$reason" "$session"
  ng_bump_counter "$session" "$hook"
  cat >&2 <<EOF
[NIGHT-GUARD BLOCKED] hook=$hook tool=$tool
command: $command
reason: $reason
suggestion: $suggestion
override: $override
EOF
}
