# stack-flow — local conventions

Read together with: ./README.md

## What this plugin owns

PreToolUse push guard, SessionStart stack-position context, and five stacked-PR skills (stack-status, stack-create, stack-submit, stack-restack, stack-reparent). The guard uses the same `permissionDecision: deny` JSON contract as `policy-gateway`. Stack state lives in `${CLAUDE_PLUGIN_DATA}/stack-flow/<repo-key>/`.

## Non-obvious invariants

- **deny() is the only way to block.** The push guard (`hooks/guard-push.sh`) emits a `permissionDecision: deny` JSON body on stdout and exits 0. Exit-non-zero would surface as a hook error, not a policy block. Claude Code reads the JSON body literally — the exit code alone does not block. Copies the `policy-gateway` template verbatim:
  ```bash
  jq -n --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
  ```
  No tool-input rewriting (`hookSpecificOutput.updatedInput`). PreToolUse does support `updatedInput`, but the guard deliberately uses `deny`: silently rewriting a developer's push command would hide what actually ran. The guard blocks and directs Claude to the appropriate skill; the skill issues the safe push.

- **Force-push strategy is A (bare lease + if-includes).** `safe-push.sh` runs:
  ```bash
  git push --force-with-lease --force-if-includes origin <branch>
  ```
  `--force-with-lease` (bare form, no `=<ref>:<sha>`) compares against the local remote-tracking ref. `--force-if-includes` closes the stale-local-ref hole by requiring the remote-tracking ref to be in the local reflog. This makes the safe push `gh`-independent and keeps the push step free of network round-trips beyond the push itself. A SHA-pinned lease (`--force-with-lease=<ref>:<sha>` via `gh pr view --json headRefOid`) is the stronger alternative but is not used here: it adds a `gh` round-trip per push and fails closed when `gh` is unavailable. If it ever becomes necessary, swap the lease form in `safe-push.sh` and drop `--force-if-includes` — with the fully-pinned `--force-with-lease=<ref>:<sha>` form it is a documented no-op (the explicit SHA already pins the value), so keeping it would be redundant rather than wrong.

- **`${CLAUDE_PLUGIN_DATA}` and the repo-key derivation.** All state is written to `${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/<repo-key>/`. `<repo-key>` is computed by `skills/_lib/repo-key.sh`:
  1. Try `git config --get remote.origin.url` → pipe through `sha1sum` → take the first 12 hex chars.
  2. Fall back to `git rev-parse --show-toplevel` → same hash → same truncation.
  The key is stable across machines that clone the same remote. It is a hash, not a human-readable name, so it never collides across repos with identical base directory names.

- **`stack-graph.json` is write-through, never cached in memory.** Every `stack-graph.sh` call reads the file fresh. Divergence (how far a branch has drifted from its parent) is never stored — it is computed live via `git merge-base` + `git rev-list --left-right --count <parent>...<branch>`. Storing divergence would make the file stale the moment a commit lands.

- **`ops.jsonl` is append-only.** Writes go through `plugins/_lib/jsonl-append.sh` to avoid torn lines under concurrent writes. Never truncate or rewrite it. See [LEDGER.md](LEDGER.md) for the entry schema.

- **`jq` is required; no string-concat JSON.** All JSON reads and writes in `skills/_lib/stack-graph.sh` go through `jq`. String-concatenation of JSON is forbidden — field values can contain characters that break naive concat (branch names with `/`, commit messages with `"`).

## Files to read first when changing this plugin

1. `hooks/guard-push.sh` — the deny contract and branch-parsing logic
2. `skills/_lib/stack-graph.sh` — the state model and divergence computation
3. `skills/_lib/repo-key.sh` — the key derivation (changing this invalidates all existing state directories)
4. `plugins/policy-gateway/hooks/scan-injection.sh` lines 30–42 — the canonical deny() template this plugin copies

## Cross-plugin dependencies

- `policy-gateway` — same `permissionDecision: deny` hook contract; if Claude Code changes how it reads PreToolUse JSON, update both plugins together
- `plugins/_lib/jsonl-append.sh` — shared append helper; used for `ops.jsonl` writes
