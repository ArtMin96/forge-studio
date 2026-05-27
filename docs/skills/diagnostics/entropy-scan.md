# Entropy Scan

`/entropy-scan` detects drift between documentation and reality across the full Forge Studio harness. It runs 14 checks — plugin count mismatches, marketplace registration gaps, hook script executability, SKILL.md frontmatter completeness, memory staleness, HARNESS_SPEC invariant compliance, skill token weight, rule provenance, tool-menu inflation, sibling reference resolution, description budget, policy registry drift, and sprawl signals — and emits a structured report with PASS / DRIFT / GAP status per check plus concrete fix lines for anything non-clean. It never modifies files. It belongs to the `diagnostics` plugin, which provides health-checking and quality-gate skills across the harness.

---

## Install

```bash
/plugin install diagnostics@forge-studio
```

```text
/entropy-scan
```

No arguments. The skill walks `plugins/**/SKILL.md`, `plugins/**/hooks.json`, `.claude-plugin/marketplace.json`, and `README.md` automatically.

## Why you need it

A plugin system with a sole maintainer grows at machine speed: skills are added, hooks are renamed, registry entries fall behind, README counts get hand-edited and diverge from reality. None of these gaps prevent the system from running today, but they compound — a stale sibling reference in `when_to_use` sends the model to a skill that doesn't exist; a README count off by one makes the header line a lie; a plugin without a marketplace entry is invisible to users. `/entropy-scan` catches this class of drift before it becomes a maintenance debt that requires archaeology to unwind.

The 14-check scope is deliberately broad so a single run surfaces the full picture. Each check either passes cleanly or produces a concrete proposed fix — not vague "check this file" advice, but the specific command or delta needed to close the gap.

## When to use it

- On a weekly schedule, to catch drift before it accumulates.
- Before a release, as a final health check alongside `/validate-marketplace`.
- After a large refactor or batch rename, when many cross-references may have shifted at once.
- Whenever the README header counts feel suspect — if the hook count in the header doesn't match what you remember adding, this is the first diagnostic to run.
- When `/rest-audit` flags quality concerns and you need the structural-drift counterpart.

Do not use it for pre-commit correctness — answering "will this install cleanly?" is [`/validate-marketplace`](validate-marketplace.md)'s job. Entropy-scan is the broader drift sweep; validate-marketplace is the focused correctness gate. Both are useful; they answer different questions.

## Best practices

- **Run it before calling a sprint done.** The README count drift check (Check 1) and the policy registry check (Check 13) are the most frequently violated. A passing entropy scan before commit prevents doc count corrections from landing as their own separate follow-up PR.
- **Treat sibling reference failures as routing bugs.** Check 11 verifies that every `Do NOT use for X — use /sibling instead` line points to a skill that actually exists. A broken sibling reference is live mis-routing advice the model will act on — fix it before the next session.
- **Use the proposed fixes verbatim.** The report emits one-line fix commands for each issue. Copy-paste is safer than paraphrasing when the fix involves a specific field name or path.
- **Check 14 sprawl signals are advisory, not emergency.** WARN thresholds on plugin count or hook-event collision count are signals to review, not automatic blockers. Read the context note: cross-plugin references from the `diagnostics` plugin are structural and do not indicate real sprawl.
- **Keep the memory staleness check (Check 5) actionable.** Files in `.claude/memory/` without a `Last verified:` date will always flag. Add a date when you write or update a memory topic so the check has something to compare.

## How it improves your workflow

`/entropy-scan` is the weekly health meter for the harness as a whole. Where `/validate-marketplace` answers "is this commit safe to ship?", entropy-scan answers "is the system still coherent after weeks of incremental change?" Running it regularly creates a rhythm: drift gets caught when it's one or two lines to fix, not after it has propagated into five downstream files. The structured, check-by-check report also makes the scan results auditable — you can compare this week's run against last week's and see exactly what moved.

## Related

- [`/validate-marketplace`](validate-marketplace.md) — pre-commit correctness (will it install?); distinct from entropy-scan's drift focus
- [`/docs-maintenance`](docs-maintenance.md) — project Markdown quality; entropy-scan covers harness drift, docs-maintenance covers prose health
- [`/rest-audit`](rest-audit.md) — outcome-oriented audit (Reliability/Efficiency/Security/Traceability); entropy-scan is the structural counterpart
- [`/ssl-audit`](ssl-audit.md) — SSL frontmatter coverage; entropy-scan flags skill quality concerns and delegates the SSL sub-check to ssl-audit
- [`/policies-list`](policies-list.md) — policy registry index; entropy-scan Check 13 validates this registry for drift
- [Architecture](../../architecture.md) — where diagnostics and the harness drift checks fit in the 8-component model
