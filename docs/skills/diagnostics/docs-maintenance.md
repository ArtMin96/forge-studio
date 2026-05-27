# Docs Maintenance

`/docs-maintenance` runs a systematic quality pass across every Markdown and MDX file in your project. You give it a mode flag — `--audit`, `--validate`, `--optimize`, `--update`, or `--comprehensive` — and it inspects documentation freshness, validates links and images, enforces style conventions, and emits a structured report with Critical / Warning / Info findings per file. In write modes it can also apply safe formatting fixes and prepare a commit. It belongs to the `diagnostics` plugin, which provides health-checking and quality-gate skills across the harness.

---

## Install

```bash
/plugin install diagnostics@forge-studio
```

```text
/docs-maintenance --audit
/docs-maintenance --comprehensive
/docs-maintenance --validate
```

The argument selects the mode. Omitting the argument or passing an unknown value defaults to `--audit` (read-only).

## Why you need it

Documentation drifts quietly. External links rot, internal cross-references go stale after renames, TODO markers get committed and forgotten, and headings fall out of hierarchy. None of these failures surface in a test suite — they accumulate invisibly until a reader hits a 404, a broken table, or a section that references a plugin that no longer exists. `/docs-maintenance` catches these issues systematically before they reach readers, and gives you a structured report with file and line numbers so fixes are never a guessing game.

The quality report it produces also doubles as an audit trail — a timestamped record of what was checked, what was clean, and what was remediated. When you run it before a release, you have evidence that documentation was validated, not just assumed to be fine.

## When to use it

- Before a release, to confirm the docs ship clean alongside the code.
- After a large refactor or rename, when internal links and cross-references are likely to have shifted.
- On a weekly or monthly cadence as a documentation health checkpoint.
- When investigating a report of broken links, stale content, or inconsistent style across the docs tree.
- Before promoting a plugin to a stable tier, as part of a broader readiness check.

Do not use it for marketplace/harness drift — discrepancies between documentation counts and what actually exists on disk belong to [`/entropy-scan`](entropy-scan.md) (drift) and [`/validate-marketplace`](validate-marketplace.md) (correctness). `/docs-maintenance` covers project-level Markdown quality only.

## Best practices

- **Start with `--audit` before any write mode.** Running read-only first lets you review the full finding list before any file is touched. Surprises in the Critical section are a signal to fix the sources, not to proceed with `--comprehensive`.
- **Treat Critical findings as blockers.** The skill stops at the first section producing critical findings unless the mode explicitly continues. A broken internal link to a file that no longer exists is a defect, not a style issue.
- **Use `--validate` to spot-check links after a rename.** A targeted link-validation pass is faster than a full scan when you know exactly what changed.
- **Reserve `--update` for when you own the commit.** Update mode may stage file changes and compose a commit message. Review the staged diff before pushing — the skill does not push, but it does stage.
- **Let the freshness signals guide your editing queue.** Files flagged as stale (>180 days) get a `stale` label in the report; files between 90 and 180 days get `warn`. Use that list to prioritize which docs to revisit next sprint.

## How it improves your workflow

`/docs-maintenance` closes the feedback loop that most projects leave open: code gets linted and tested automatically, but documentation is reviewed by hand — if at all. Running this skill before releases or on a regular schedule turns documentation health from a manual inspection into a repeatable, evidence-producing check. The structured report format makes findings actionable at the file-and-line level rather than vague impressions, and the mode system means you can get read-only signal in CI and apply fixes locally when you're ready.

## Related

- [`/entropy-scan`](entropy-scan.md) — drift between documentation counts and actual plugin/skill state; complements docs-maintenance, which covers prose quality
- [`/validate-marketplace`](validate-marketplace.md) — focused pre-commit correctness check for marketplace registration and frontmatter
- [`/md-structure`](md-structure.md) — audits a single CLAUDE.md against the four Karpathy sections; docs-maintenance covers the full doc tree, md-structure focuses on CLAUDE.md structure specifically
- [`/verify-refs`](../evaluator/verify-refs.md) — checks that cross-references in task artifacts exist; docs-maintenance is the full-doc-tree counterpart
- [Architecture](../../architecture.md) — where diagnostics fits in the 8-component harness model
