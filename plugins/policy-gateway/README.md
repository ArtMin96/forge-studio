# policy-gateway

Pre-execution policy gate. Scans for PII and secrets, detects prompt-injection attempts in tool input, and audits sensitive operations before they run.

## What it does

Sits between the planner and execution. If a Bash command is about to leak a secret, fetch a poisoned URL, or run a sensitive op (chmod, network call, db drop), the gate fires *before* the side effect — same `permissionDecision: deny` contract used by `behavioral-core`'s destructive-command guard.

Rules live in `rules.d/` so the self-evolution loop (`/evolve`) can propose tightenings or relaxations against trace evidence.

## When to use

You always want it on. The PII scanner alone has caught accidental secret leaks in commit messages and chat replies. Disable rule-by-rule (drop a file from `rules.d/`) rather than turning the whole plugin off.

## How it works

```text
 PreToolUse (Edit/Write)        ──► scan-secrets.sh    regex + entropy check on input
 PreToolUse (Bash/Edit/Write)   ──► scan-injection.sh  flag known prompt-injection markers
                                                       ↓ deny | allow
 PostToolUse (Edit/Write)       ──► audit-sensitive-ops.sh   log sensitive-op outcomes
```

A `deny` blocks the tool call. A `warn` lets it through but logs to the ledger.

## Skills

| Skill | Purpose |
|---|---|
| `/policy-audit` | Report secret/injection blocks and sensitive-op audits from the ledger. Also scans the working tree for secrets that pre-date the plugin |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `PreToolUse` (`Edit\|Write`) | scan-secrets | Block on detected secret in input |
| `PreToolUse` (`Bash\|Edit\|Write`) | scan-injection | Block on prompt-injection markers |
| `PostToolUse` (`Edit\|Write`) | audit-sensitive-ops | Log sensitive-op outcomes to the ledger |

## Disable

`/plugin disable policy-gateway@forge-studio`. You lose the secret guard; replace it with another scanner before disabling in any shared environment.
