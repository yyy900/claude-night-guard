# Threat model

Unattended Claude has a different threat profile than interactive Claude.

## Risks

| # | Risk | Hard-blockable? | Approach |
|---|---|---|---|
| 1 | Irreversible local damage (`rm -rf`, `git reset --hard`) | Yes | PreToolUse block |
| 2 | Irreversible remote damage (`push --force`, branch delete) | Yes | PreToolUse block |
| 3 | Secret exfiltration (commit `.env`, write key to log) | Mostly | PreToolUse block + PostToolUse audit |
| 4 | Edits outside the project (`~/.zshrc`, system files) | Yes | PreToolUse block |
| 5 | Supply-chain RCE (`curl … \| sh`) | Yes | PreToolUse block |
| 6 | Silent quality decay (swallowed exceptions, fallback paths) | No | CLAUDE.md + post-hoc audit (out of scope) |
| 7 | Scope creep (model fixes things you didn't ask) | No | Prompt-layer (out of scope) |
| 8 | Cost runaway (infinite tool loops) | Partial | UserPromptSubmit halt after N blocks; provider rate limits |
| 9 | Prompt injection via fetched URLs | No | Sanitize at fetch boundary (out of scope) |

## What this repo handles

Rows 1–5 and the looping behavior of 8. These share a property: they are **mechanically detectable at the harness layer**, before the tool fires.

## What this repo does not handle

Rows 6, 7, 9: pure judgment calls. No PreToolUse regex catches "model decided to wrap legitimate code in `try/except pass`." These need prompt-layer guardrails (CLAUDE.md rules, post-run review skills like `/review`) and possibly a separate offline auditor.

Row 8 cost cap: belongs in the provider/API layer (`DISABLE_NON_ESSENTIAL_MODEL_CALLS`, rate limits). We catch the *symptom* (looping on the same blocked op) but not raw API spend.

## Why PreToolUse blocks instead of warns

Unattended runs have no human to dismiss a warning. A warn-only hook is functionally a comment.

## Why we don't auto-rollback in PostToolUse

Rollback is itself destructive. `git reset --hard HEAD~1` to undo a bad commit can lose unrelated work in the index. A human reviewing the audit log decides. PostToolUse alerts; it does not act.

## Why every block has an override

Hard rules with no escape hatch produce one of two failure modes:

1. Agents loop forever trying variations to bypass the block.
2. Users disable the entire system when it blocks a legitimate case.

Explicit `NIGHT_GUARD_ACK=<name>` makes overrides *visible* (logged) instead of *invisible* (system disabled).

## Why the 3-block halt is conservative

A correctly-functioning agent should be blocked rarely. Three blocks usually means it's stuck on something needing human judgment. The halt forces a summary so the user can intervene in the morning without reading the full transcript.

## What an attacker could do

These hooks defend against the *model* making mistakes, not against a *compromised* agent. If an attacker controls the model's output, they can also write hook bypass commands. PreToolUse is not a security boundary against malicious code — it's a safety net against unintentional damage. Real security boundaries live in the OS sandbox layer.
