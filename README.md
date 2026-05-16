# claude-night-guard

Safety guardrails for Claude Code running unattended (e.g. overnight). Hooks that block dangerous tool calls **before** they execute, feed structured reasons back to Claude so it self-recovers, and write an audit log so you can see what happened in the morning.

Community-maintained. PRs welcome — every hook is one shell script and one test case.

## What it does

| Risk | Hook | Layer |
|---|---|---|
| `rm -rf` | `block-rm-rf` | PreToolUse / Bash |
| `git push --force` / `-f` / `+refspec` | `block-force-push` | PreToolUse / Bash |
| Committing or editing `.env`, keys, credentials | `block-env-commit` | PreToolUse / Bash + Edit + Write |
| Edits outside cwd | `block-out-of-cwd-edit` | PreToolUse / Edit + Write |
| `curl … \| bash` and friends | `block-curl-pipe-sh` | PreToolUse / Bash |
| Secrets in HEAD commit | `audit-commit-secrets` | PostToolUse / Bash (alert only, no rollback) |
| ≥3 blocks in one session | `halt-on-repeated-blocks` | UserPromptSubmit (injects HALT message) |

## How it works

PreToolUse hooks run **before** the tool executes, so blocking is atomic — no rollback needed. On block, the hook writes a structured reason to stderr, which Claude Code feeds back as the tool's result. Claude sees `[NIGHT-GUARD BLOCKED] reason: … suggestion: … override: …` and either re-routes or, for legitimate cases, re-runs with an explicit override prefix.

Every block appends one line to `~/.claude/night-guard/incidents.jsonl`. After three blocks in a session, `UserPromptSubmit` injects a halt message instructing Claude to stop and summarize, so an agent can't quietly grind through the night hitting the same wall.

## Install

```bash
git clone https://github.com/yyy900/claude-night-guard
cd claude-night-guard
./install.sh overnight-strict
```

Merges into `~/.claude/settings.json` (backup saved to `.bak`). Re-running is idempotent — old night-guard entries are replaced, others untouched.

Uninstall:

```bash
./uninstall.sh
```

## See what was blocked

```bash
./view-incidents.sh 24h   # or 30m, 7d
```

## Overriding a block

When agent reasoning genuinely requires a blocked operation, it re-runs with an explicit ack prefix:

```bash
NIGHT_GUARD_ACK=rm-rf rm -rf ./build-cache
NIGHT_GUARD_ACK=force-push git push --force-with-lease origin feature
NIGHT_GUARD_ACK=curl-pipe curl https://get.pnpm.io/install.sh | bash
```

The override still logs to the incident log so you can review what was bypassed.

For `block-out-of-cwd-edit`, set `NIGHT_GUARD_ALLOW_PATHS=/path/one:/path/two` to extend the allowed-prefix list.

## Test

```bash
bash tests/run-tests.sh
```

## Contributing a hook

See [CONTRIBUTING.md](CONTRIBUTING.md). One new hook = one shell script in `hooks/pre/`, one test block in `tests/run-tests.sh`, one entry in a preset.

## What this does **not** do

- It will not catch the model misjudging *what to build* — only what tools to invoke. Code quality regressions (swallowed exceptions, silent fallbacks) need a different layer (CLAUDE.md, post-hoc audit).
- It does not auto-rollback. PostToolUse alerts you to a bad commit; rolling back is itself destructive and stays a human decision.
- It does not enforce cost caps. Use your provider's rate limits and `DISABLE_NON_ESSENTIAL_MODEL_CALLS` for that.

## Threat model

[Threat model](docs/threat-model.md) for the design rationale and what's intentionally out of scope.
