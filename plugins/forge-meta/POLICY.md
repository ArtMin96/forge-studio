# forge-meta Controllability Policy

This document defines the paths that the self-evolution loop may not modify.
The invariant originates from AHE (2604.25850 p.5): the evolution agent must not
be able to disable its own oversight mechanisms.

## Protected Paths

The following paths are non-editable when a request originates from the
evolution loop (i.e., when the `FORGE_META_EVOLVE=1` environment variable
is set):

- `plugins/evaluator/skills/verify/`
- `plugins/evaluator/skills/healthcheck/`
- `plugins/diagnostics/skills/entropy-scan/scripts/count.sh`
- `CLAUDE.md`
- `HARNESS_SPEC.md`
- `plugins/forge-meta/POLICY.md`

## Enforcement Mechanism

The `pre-edit-guard.sh` hook (PreToolUse: Edit|Write) reads the target file
path from `tool_input.file_path`. If the path falls under a protected entry
above and `FORGE_META_EVOLVE=1` is set, the hook exits with code 2 (block)
and names this document in the error message.

When `FORGE_META_EVOLVE` is unset, the hook exits 0 silently. Human users
can edit any path without restriction — the guard applies only to automated
evolution-loop writes.

## Rationale

Without this boundary, an auto-tune iteration could rewrite `/verify` to
always return PASS, or alter `count.sh` to hide drift. Separating evolution
logic into `forge-meta` and placing the protected-path list here (rather
than inside the evolution skill itself) means the boundary survives any
mutation of the skill's body.

The list is intentionally short. Expanding it requires a human edit to this
file — a deliberate friction point.
