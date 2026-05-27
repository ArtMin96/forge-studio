# Sync Discovery

`/sync-discovery` compares a regex pattern across two repositories and classifies every match as present only in repo A, present only in repo B, or present in both — with a content-hash divergence flag when the matched lines differ between the two repos. It belongs to the `cross-repo` plugin, which provides cross-repository coordination and discovery skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install cross-repo@forge-studio
```

```bash
python3 plugins/cross-repo/skills/sync-discovery/scripts/discover.py \
  --repo-a /path/to/repo-a \
  --repo-b /path/to/repo-b \
  --pattern 'def process_' \
  --out /tmp/discovery.json
```

`--pattern` is a regular expression passed to `git grep -nE`. `--out` is the path where `discovery.json` is written.

## Why you need it

Before fanning out a fix or convention change across sibling repositories, you need to know whether the pattern you are targeting actually exists in each repo, and whether the existing implementations have drifted from each other. Running `/federated-fan-out` against repos where the pattern is absent — or already canonical — wastes subagent budget and produces noisy results. Running it against repos where the pattern has diverged without knowing the divergence means the patch may land differently than intended.

`/sync-discovery` answers the preliminary question precisely: here is what exists in each repo, here is what is shared, and here is where the shared instances have diverged. The `divergent: true` flag on an `in_both` entry is the signal that the two repos have independently evolved the same pattern and may need different handling.

## When to use it

- Before a `/federated-fan-out` run, to confirm the pattern is present where expected and absent where not.
- When investigating whether a utility, middleware, or configuration block has been copied between repos and whether the copies are in sync.
- When a convention change is planned and you want to know the exact file and line locations in each repo before writing the patch prompt.

Do not use it for dispatching work to multiple repos — use [`/federated-fan-out`](federated-fan-out.md) instead. Do not use it to aggregate results from a completed fan-out run — use [`/aggregate-results`](aggregate-results.md) for that.

## Best practices

- **Use qualified patterns.** A narrow regex like `class AuthMiddleware` produces clean, actionable results. A broad pattern like `auth` produces so many matches that the classification is difficult to act on. Invest thirty seconds in tightening the pattern before running.
- **Both paths must be git repositories.** `git grep` is the search engine. Non-git directories exit with a clear error. Verify both paths are initialized git repos before invoking.
- **Treat `divergent: true` as a review gate.** An `in_both` entry with `divergent: true` means the same pattern exists in both repos but the implementations differ. This is not automatically a problem, but it should be reviewed before applying a uniform patch — the patch may conflict with one side's diverged version.
- **Binary files are skipped automatically.** `git grep` skips binary files by design. If the pattern could appear in a generated or binary file that matters for the comparison, those files require separate handling.

## How it improves your workflow

`/sync-discovery` provides the reconnaissance step that makes cross-repo operations precise rather than speculative. Instead of running a fan-out and discovering mid-flight that three repos have the pattern and two do not, you run discovery first, confirm the landscape, and write a prompt that accounts for what is actually there. The `discovery.json` output is structured so that the three sets — `only_in_a`, `only_in_b`, `in_both` — can be read directly into the repos file for a subsequent fan-out targeting only the relevant subset.

## Related

- [`federated-fan-out.md`](federated-fan-out.md) — the dispatch step to run after discovery confirms the target landscape
- [`aggregate-results.md`](aggregate-results.md) — collects fan-out results after the operation runs
- [Architecture](../../architecture.md) — multi-agent decomposition and cross-repo coordination in the 8-component harness model
