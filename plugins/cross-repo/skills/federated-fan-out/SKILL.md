---
name: federated-fan-out
description: Use when the same operation (convention change, audit, patch) must be applied to 2–5 independent sibling repos. Spawns one subagent per repo with a shared prompt template, captures per-repo results under a workspace ledger, and prints a summary table.
when_to_use: Reach for this when repos are independent (no cross-repo shared state in this batch) and the operation is the same for each. Do NOT use for pattern comparison between repos — use `/sync-discovery` instead; do NOT use to collate an already-completed run — use `/aggregate-results` instead.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Task
scheduling: user has 2-5 sibling repos requiring the same operation (sync convention, apply patch, run audit) AND each repo has independent state (no cross-repo dependencies in this batch)
structural:
  - Read the repos-file (one absolute path per line, ≤5 entries)
  - For each repo, spawn a subagent with the shared prompt template and working directory set to the repo path
  - Capture per-repo result (exit status, summary, artifact paths) under ~/.forge-cross-repo/<run-id>/<repo-basename>/result.json
  - Write a workspace ledger entry per repo per phase (start, complete, failed) to ~/.forge-cross-repo/<run-id>/ledger.jsonl
  - Print a final per-repo summary table
logical: each repo has a result.json under the workspace; ledger contains one start + one terminal (complete|failed) line per repo; total subagent count equals repo count; no subagent runs without a workspace entry
---

# /federated-fan-out — Cross-Repo Parallel Dispatch

Apply the same operation to 2–5 sibling repos in parallel. Each repo gets its own subagent; results land in a shared workspace for later aggregation.

## Invocation

```bash
python3 plugins/cross-repo/skills/federated-fan-out/scripts/run.py \
  --repos /path/to/repos.txt \
  --prompt /path/to/prompt.txt \
  --run-id my-run-id
```

Use `--mock` during testing to skip real `claude -p` invocations and produce deterministic results.

## repos-file format

One absolute path per line, ≤5 entries:

```
/home/user/code/repo-a
/home/user/code/repo-b
/home/user/code/repo-c
```

## prompt-file format

A shell snippet or natural-language task description passed verbatim to each subagent.

## Workspace output

```
~/.forge-cross-repo/<run-id>/
  ledger.jsonl                      # append-only; one line per repo per phase
  <repo-basename>/
    result.json                     # {status, exit_code, stdout_tail, stderr_tail, summary}
```

## Examples

### Example 1: convention sync across 3 repos

Input: `repos.txt` lists 3 paths; `prompt.txt` says "Update CLAUDE.md sections to match the canonical 4-section template; commit on a branch named `chore/claude-md-sync`."

Output: `~/.forge-cross-repo/sync-2026-05-19/`
```text
ledger.jsonl                      # 6 lines: 3 start + 3 complete
repo-a/result.json                # {"status":"complete","exit_code":0,"summary":"committed on chore/claude-md-sync"}
repo-b/result.json                # {"status":"complete","exit_code":0,"summary":"already canonical, no commit"}
repo-c/result.json                # {"status":"complete","exit_code":0,"summary":"committed on chore/claude-md-sync"}
```
Stdout: a 3-row summary table; verdict matrix runs via `/aggregate-results sync-2026-05-19`.

### Example 2: one repo path missing

Input: `repos.txt` lists 3 paths but `/home/user/code/repo-c` was renamed.

Output: 2 repos complete; `repo-c/result.json` contains `{"status":"failed","exit_code":1,"stderr_tail":"path does not exist: /home/user/code/repo-c"}`. Ledger ends with one `failed` line for repo-c instead of `complete`. Exit code from `run.py` is 1 (any failure surfaces non-zero).

## Execution Checklist

- [ ] repos-file has ≤5 entries (validated at startup)
- [ ] Each path in repos-file is an absolute path to an existing directory
- [ ] prompt-file exists and is non-empty
- [ ] run-id is unique (or intentionally reusing a workspace)
- [ ] After completion, run `/aggregate-results <run-id>` for the verdict matrix

## Known Failure Modes

- Subagent session cost: each `claude -p` is a fresh session with no warm context. Budget accordingly.
- If a repo path does not exist, that repo's result is `status: failed` with a descriptive error.
- The ≤5 limit is hard: 6+ repos exit 1 immediately with a clear message.
