# Change Manifest

`/change-manifest` writes a structured entry to `.claude/evolution/change_manifest.jsonl` — the append-only evolution ledger that every other `forge-meta` skill reads. It belongs to the `forge-meta` plugin, which manages Forge Studio's self-evolution boundary.

---

## Install

```bash
/plugin install forge-meta@forge-studio
```

```text
/change-manifest --type hook-edit --description "wired SubagentStop for manifest capture" --files "plugins/forge-meta/hooks/manifest-writer.sh"
```

The full argument surface is `--type <type> --description <desc>` (required) plus optional `--files`, `--predicted-fixes`, `--risk-tasks`, `--constraint-level`, and `--why-this-component`. For non-trivial changes, the richer transactional fields (`read_set`, `write_set`, `assumptions`, `verifier_obligations`, evidence bundle) are passed as environment variables before calling `manifest-writer.sh` directly.

## Why you need it

A session that modifies plugins, hooks, or skills without recording what it did and why produces a diff that is technically correct but forensically opaque. When a later session needs to attribute a regression, or when `/session-digest` tries to roll up what happened, it reads the evolution ledger. If the ledger is sparse, those downstream reads come back empty.

`/change-manifest` gives every meaningful change a structured identity: an auto-generated ID, a timestamp, the session and agent that made it, the files touched, the failure pattern it addresses, and — for non-trivial changes — the read set, write set, assumptions made, and a `verifier_obligations` shell command that `/failure-attribute` can re-run during attribution. An evidence bundle with `checks_run` and explicit `untested_regions` signals exactly which verification happened and which did not, making the ledger honest rather than optimistic.

## When to use it

- A generator or reviewer agent has just finished a meaningful change to plugin files, hooks, or skills and needs to declare it to the evolution ledger.
- You want to record predicted fixes, downstream risk tasks, or a constraint level alongside the change.
- You are scripting a pipeline and want to supply full transactional state — read set, write set, assumptions — so `/failure-attribute` can reconstruct causality later.

The `manifest-writer.sh` SubagentStop hook writes entries automatically when an agent emits a `change_manifest: {...}` marker line on stdout or when git shows recently modified files. Invoke this skill directly only to record a change the hook could not auto-detect, or to supply the richer transactional fields the hook does not populate from git state alone.

Do not use it for session-end summaries — use [`/session-digest`](session-digest.md) instead.

## Best practices

- **Supply `read_set` and `write_set` on non-trivial changes.** Passing these via `MANIFEST_READ_SET` and `MANIFEST_WRITE_SET` lets downstream tools flag mismatches — if `write_set` contains files not in `read_set`, that signals the agent wrote without reading first.
- **Quote `verifier_obligations` literally.** The field should contain the exact shell command — `bash ...` or `python3 ...` — that confirms the change held up. Vague prose is not rerunnable; a literal command is.
- **Set `untested_regions` explicitly, even as an empty list.** An absent field means "unknown coverage" and is treated as suspect by `/failure-attribute`. An explicit `[]` means fully tested. Honesty here is more valuable than optimism.
- **Validate after writing.** Run `python3 -c "import json; [json.loads(l) for l in open('.claude/evolution/change_manifest.jsonl')]"` to confirm the new line is well-formed JSON. A malformed line silently breaks manifest readers.
- **Never rewrite or sort prior entries.** The manifest is append-only. `/evolution-history` and `/manifest-analyze` assume monotonic order; rewriting disrupts their chronology.

## How it improves your workflow

Every entry written by `/change-manifest` becomes a node in the harness's memory. [`/session-digest`](session-digest.md) reads it at session end to produce a compact rollup. [`/evolution-history`](evolution-history.md) renders it as a dated timeline across sprints. [`/manifest-analyze`](manifest-analyze.md) aggregates failure patterns and risk tasks across the full ledger. `/failure-attribute` re-runs the `verifier_obligations` commands to find which change broke what. The richer you make each entry, the more useful all of these downstream reads become.

## Related

- [`/session-digest`](session-digest.md) — reads the current session's manifest entries and rolls them into a per-session summary
- [`/evolution-history`](evolution-history.md) — renders the full ledger as a reverse-chronological timeline
- [`/manifest-analyze`](manifest-analyze.md) — aggregates failure patterns and constraint levels across the manifest
- [`/auto-tune-skill`](auto-tune-skill.md) — writes a manifest entry when a proposal is applied; reads the ledger to track prior tuning runs
- [Architecture](../../architecture.md) — execution traces and memory in the 8-component harness model
