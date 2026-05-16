---
name: safe-mode
description: Use to toggle the safe-mode flag at .claude/safe-mode. The flag is written automatically by consecutive-failure-guard once tool failures hit FORGE_SAFE_MODE_THRESHOLD (default 5), and block-destructive.sh denies every Bash/Write/Edit while it exists. /safe-mode off clears the flag, logs the exit, and prompts /postmortem; /safe-mode on enters manually; /safe-mode status reports current state.
when_to_use: Reach for "/safe-mode off" after diagnosing the failure chain that auto-triggered the lock, or "/safe-mode on" when about to perform a risky operation that you want the harness to block until you explicitly clear it. Do NOT use to skip a postmortem — clearing the flag without root-cause analysis defeats the graceful-degradation contract. Do NOT use for routine harness health checks — use `/healthcheck` instead; safe-mode only toggles the destructive-edit lockdown.
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

## Escalation Brief

When this skill activates — automatically via consecutive-failure-guard, or manually via `/safe-mode on` — emit a structured brief in this exact shape so a human can decide fast. Reproduce the labels verbatim; a downstream parser detects a brief by them.

```text
CONTEXT: <one line — what was the agent trying to do>
TRIGGER: <one line — what stopped it: failure-count threshold, low-confidence signals, denied permission, conflicting evidence>
OPTIONS:
1. <option, agent can do this without help>
2. <option, requires your action>
3. <option, requires your action>
RECOMMENDATION: <option #N>. <one-line reason>

Waiting for instruction. <thing the agent is paused on> is not blocked yet.
```

The brief is not a substitute for `/postmortem` after `/safe-mode off` — it precedes the human decision; postmortem follows the resolution.

Input: consecutive-failure-guard wrote `.claude/safe-mode` after 5 failed `pytest -k user_signup` runs; the agent invokes `/safe-mode status`.
Output:
```text
SAFE MODE: active
Entered: 2026-05-16T14:22:01Z
Reason: consecutive-failures
Failure counter: 5

CONTEXT: Reproduce the user_signup test failure flagged by /verify.
TRIGGER: Failure-count threshold (5 consecutive pytest exits, last was assertion error in fixture teardown).
OPTIONS:
1. Roll back the last commit and re-run from a known-green tree.
2. Show you the failing fixture and the last three diff hunks for a manual decision.
3. Skip user_signup and gate only on the other 41 tests for now.
RECOMMENDATION: Option 2. The failure is in fixture teardown, not the assertion under test — a human glance at the diff is cheaper than another speculative rewrite.

Waiting for instruction. The working tree is not blocked yet — no further edits will be attempted until you reply.
```

Input: the agent invokes `/safe-mode on risky-migration` before running a one-shot database schema change it cannot easily undo.
Output:
```text
Safe-mode active. Mutations blocked until /safe-mode off.

CONTEXT: Apply the `add_audit_columns` migration to the production-shape staging DB before the release window.
TRIGGER: Manual entry — operation is one-shot and the rollback path requires a snapshot restore.
OPTIONS:
1. Run the migration with `--dry-run` first and report the planned DDL.
2. Pause for you to confirm the migration plan and the rollback steps you want recorded.
3. Hand off the migration entirely — I draft the SQL, you run it.
RECOMMENDATION: Option 1. A dry-run is reversible and surfaces any unexpected DDL before the destructive write.

Waiting for instruction. The migration is not blocked yet — the connection is open and the dry-run command is queued.
```
