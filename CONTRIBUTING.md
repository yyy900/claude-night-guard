# Contributing

Every hook is a small shell script. Adding one is mechanical:

## 1. Write the hook

Create `hooks/pre/block-<thing>.sh` (or `hooks/post/audit-<thing>.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/feedback.sh"

ng_parse_input
[[ "$NG_TOOL_NAME" == "Bash" ]] || exit 0

cmd="$NG_BASH_COMMAND"
[[ "$cmd" == NIGHT_GUARD_ACK=<thing>* ]] && exit 0

if <pattern matches dangerous case>; then
  ng_block_and_log "block-<thing>" "Bash" "$cmd" \
    "<one-line reason>" \
    "<what to do instead>" \
    "NIGHT_GUARD_ACK=<thing> <command>" \
    "$NG_SESSION_ID"
  exit 2
fi
exit 0
```

After parsing, you have:
- `NG_TOOL_NAME` — `Bash`, `Edit`, `Write`, etc.
- `NG_BASH_COMMAND` — the command string (Bash only)
- `NG_EDIT_FILE_PATH` — the file path (Edit/Write only)
- `NG_SESSION_ID` — for incident logging and rate-limiting

## 2. Make it executable + add to a preset

```bash
chmod +x hooks/pre/block-<thing>.sh
```

Edit `presets/overnight-strict.json` and add an entry under the relevant matcher.

## 3. Write at least one positive + one negative test

In `tests/run-tests.sh`:

```bash
out=$(run_hook "$HOOKS/pre/block-<thing>.sh" "Bash" "<dangerous command>"); rc=$?
assert "<thing> blocks <case>" 2 $rc "NIGHT-GUARD BLOCKED" "$out"

out=$(run_hook "$HOOKS/pre/block-<thing>.sh" "Bash" "<safe command>"); rc=$?
assert "<thing> allows <safe case>" 0 $rc "" "$out"
```

Run `bash tests/run-tests.sh`. All tests must pass.

## Design rules

1. **Pre-hooks block atomically.** Never let the tool partially execute. If you can't decide pre-execution, it belongs in `hooks/post/` as an alert, not a block.
2. **Every block has an override.** Either an `NIGHT_GUARD_ACK=<name>` prefix for Bash, or an env var, or "user must do it manually" — but the message must say which.
3. **Stderr is for Claude, not humans.** Write a structured reason + suggestion + override line. Claude reads this and re-routes; vague messages cause loops.
4. **Log every block.** Always call `ng_block_and_log`, never just `exit 2`. Without the audit trail you can't tell what happened overnight.
5. **Tight regex.** False positives are worse than false negatives here — a hook that fires on safe commands makes users disable the whole system. Test the edge cases.
6. **One risk per hook.** Don't bundle. `block-rm-rf` doesn't also check force-push. Composability beats cleverness.
7. **No external dependencies.** Bash + python3 (stdlib only) + standard unix tools. The hook has to run on a fresh laptop with no `brew install` step.

## Submitting a pitfall (event you want others to learn from)

If your night-guard fired on something interesting (or *failed* to fire on something it should have), open an issue with:

- The tool call (sanitize secrets)
- What night-guard did or didn't do
- What you wish had happened

These shape future hooks.
