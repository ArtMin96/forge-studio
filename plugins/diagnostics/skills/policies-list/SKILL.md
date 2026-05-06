---
name: policies-list
description: Print every policy enforcement point declared in plugins/diagnostics/registry/policies.json — id, verdict, plugin, hook event, severity, bypass — grouped by verdict. Single discoverable index of what the harness blocks, anchors, nudges, or logs at runtime.
when_to_use: Reach for this when onboarding to forge-studio, before turning a plugin off and wanting to know what enforcement disappears with it, or while writing docs that need to cite a policy by id (FS01–FS42). Do NOT use to *change* a policy — the registry indexes existing scripts; edits go in the source script and `rules.d/` patterns, not here.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
logical: report shows every registry entry grouped by verdict (deny/gate/anchor/nudge/log) with its FS-id, plugin, hook event, and bypass mechanism
---

# /policies-list — Policy Enforcement Index

Read `plugins/diagnostics/registry/policies.json` and print one row per enforcement point. The registry is the single discoverable index of what the harness blocks, anchors, nudges, or logs at runtime.

## Verdict semantics

| Verdict | Mechanism | Effect |
|---|---|---|
| `deny` | PreToolUse hook returns exit 2 / `{"decision":"block"}` | Tool call refused |
| `gate` | PreToolUse hook returns deny only when conditional check fires | Tool call sometimes refused |
| `anchor` | UserPromptSubmit / SessionStart hook injects system-prompt text | Behavioral steer, no enforcement |
| `nudge` | PostToolUse hook injects an advisory message | Soft suggestion, ignorable |
| `log` | PostToolUse hook appends to ledger / counter | Telemetry feeds other policies |

## Run

```bash
bash plugins/diagnostics/skills/policies-list/scripts/render.sh
```

## Output Format

```markdown
## Policy Enforcement Index

**Source:** plugins/diagnostics/registry/policies.json
**Entries:** {N}

### deny
| FS-id | Plugin | Hook | Bypass | Description |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |

### gate
...

### anchor
...

### nudge
...

### log
...
```

## Failure Modes

- **Registry missing or malformed:** the script reports the parse error and exits 0 — every other diagnostic still works.
- **Implementation path drift:** `/entropy-scan` Check 13 catches registry rows whose `implementation` path no longer exists, and enforcement scripts on disk that have no registry entry. Fix in the registry, not by deleting evidence.
