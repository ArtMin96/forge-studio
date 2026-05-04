---
name: safe-mode
description: Use to toggle the safe-mode flag at .claude/safe-mode. The flag is written automatically by consecutive-failure-guard once tool failures hit FORGE_SAFE_MODE_THRESHOLD (default 5), and block-destructive.sh denies every Bash/Write/Edit while it exists. /safe-mode off clears the flag, logs the exit, and prompts /postmortem; /safe-mode on enters manually; /safe-mode status reports current state.
when_to_use: Reach for "/safe-mode off" after diagnosing the failure chain that auto-triggered the lock, or "/safe-mode on" when about to perform a risky operation that you want the harness to block until you explicitly clear it. Do NOT use to skip a postmortem — clearing the flag without root-cause analysis defeats the graceful-degradation contract.
disable-model-invocation: true
argument-hint: <on|off|status>
allowed-tools:
  - Read
  - Write
  - Bash
logical: .claude/safe-mode flag toggled to the requested state; ledger entry appended
---

# /safe-mode — Graceful-Degradation Toggle

Controls `.claude/safe-mode`. When present, `block-destructive.sh` denies Bash/Write/Edit. Exists to force a human checkpoint after repeated failures, per TRAE §5.2.4 "Graceful Degradation".

## Subcommands

### `/safe-mode status`
Read the flag. Print:
```text
SAFE MODE: <active|inactive>
Entered: <ISO8601> (if active)
Reason: <reason> (if active)
Failure counter: <N> (if active)
```

### `/safe-mode on [reason]`
Manual entry. Write the flag:
```json
{"entered_at":"<UTC>","reason":"<reason or 'manual'>","counter":0}
```
Append ledger entry `{operator:"safe-mode-enter", trigger:"/safe-mode", actor:"behavioral-core:/safe-mode"}`.
Report: `Safe-mode active. Mutations blocked until /safe-mode off.`

### `/safe-mode off`
1. Refuse if no flag exists: `Safe-mode is not active. Nothing to do.`
2. Delete `.claude/safe-mode`.
3. Reset the failure counter: `rm -f /tmp/claude-failure-guard/<session>/consecutive-failures`.
4. Append ledger entry `{operator:"safe-mode-exit", trigger:"/safe-mode", actor:"behavioral-core:/safe-mode"}`.
5. **Suggest `/postmortem`** on the failure chain — the whole point of the forced checkpoint is to learn, not to skip past it:
   ```
   Safe-mode cleared. The failure chain that triggered it is still worth understanding.
   Recommend: run /postmortem on the root cause before continuing.
   ```

## Integration

- **Writer:** `plugins/context-engine/hooks/consecutive-failure-guard.sh` writes the flag at `FORGE_SAFE_MODE_THRESHOLD` (default 5).
- **Reader:** `plugins/behavioral-core/hooks/block-destructive.sh` Layer 5.
- **Ledger:** All entries use the SEPL schema so `/rest-audit` Reliability axis and `/lineage-audit` can inspect them.
- **Partner skill:** `/postmortem` (evaluator plugin) — the intended follow-up after every exit.

## Failure Modes

- `.claude/safe-mode` exists but malformed JSON → treat as active (safer default); `/safe-mode off` still clears it.
- Ledger write fails → flag state still changes (the flag is the source of truth; ledger is audit metadata).

## Do NOT

- Do not clear the flag silently or auto-reset it. The human checkpoint is the value.
- Do not extend safe-mode with new blocking scopes in this skill — that belongs in block-destructive.sh, which is the enforcement layer.
