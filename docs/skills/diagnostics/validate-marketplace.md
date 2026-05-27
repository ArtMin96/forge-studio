# Validate Marketplace

`/validate-marketplace` is the pre-commit correctness check for plugin integrity. It runs 12 mechanical checks — marketplace JSON parsability, plugin directory registration, SKILL.md frontmatter schema, hook script executability, hooks.json parsability, agent schema and skill-preload coherence, skill size budget, plugin version sync, bash syntax, registry budget, body line cap, and name shape — and emits a structured report with OK / FAIL per check plus a VALID / INVALID overall verdict. It belongs to the `diagnostics` plugin, which provides health-checking and quality-gate skills across the harness.

---

## Install

```bash
/plugin install diagnostics@forge-studio
```

```text
/validate-marketplace
```

No arguments. The skill reads `.claude-plugin/marketplace.json`, all `plugins/**/SKILL.md` files, all `plugins/**/hooks.json` files, and all hook scripts automatically.

## Why you need it

Plugin changes break in specific, predictable ways: a directory renamed without updating `marketplace.json` produces a silent registration mismatch; a SKILL.md frontmatter with a backtick-prefixed field value fails YAML parsing at install time; an agent that preloads a `disable-model-invocation: true` skill gets silently dropped at runtime with no error. None of these failures surface until the plugin is installed or the agent runs — which may be in another user's environment, not your own.

`/validate-marketplace` catches this entire class of correctness errors before commit. The checks are mechanical and deterministic: each one either passes or produces a specific failure payload with the offending file and reason. You do not need to know the YAML schema or the frontmatter field list by heart — the validator knows them and tells you exactly which field on which file violates which rule.

## When to use it

- Before committing any change to `plugins/` — this is the primary use case. Running it as a pre-commit step (or wiring it into CI) catches registration, schema, and syntax errors before they ship.
- After manually editing `marketplace.json` or a SKILL.md frontmatter, to confirm the edit is valid.
- Before bumping a plugin version, to confirm version sync between `plugin.json` and `marketplace.json` is intact.
- When `/entropy-scan` reports a registration gap and you want a focused pass that tells you exactly which check fails and why.

Do not use it for documentation-versus-reality drift — stale README counts, mismatched header numbers, and outdated Active Hooks paragraphs belong to [`/entropy-scan`](entropy-scan.md). `/validate-marketplace` answers "will this install succeed?"; entropy-scan answers "is the documentation still accurate?". A commit can pass `/validate-marketplace` while entropy-scan reports README drift, and that is by design.

## Best practices

- **Stop at the first FAIL if you are time-constrained.** The skill runs all 12 checks and produces a full report, but it notes that stopping at the first failure is reasonable when you need a fast pre-commit gate. Fix the first failure, re-run, and repeat.
- **Read the Known Failure Modes section before chasing phantom errors.** YAML backtick-prefix failures, missing closing `---` delimiters, and source-path mismatches after a rename are the most common sources of false-looking failures. The reported error for all three looks like a different problem than it is — check the delimiter and the source path first.
- **Treat disabled-skill preload warnings as runtime silent failures.** Check 6 flags any agent whose `skills:` list includes a `disable-model-invocation: true` skill. At runtime Claude Code silently drops the preload and the agent runs without it — no error, no warning. The validator is the only place this misconfiguration surfaces before it affects a real session.
- **Size budget failures compound after compaction.** Check 7 classifies skills into three bands: under 8,000 characters (OK), 8,001–20,000 (truncation risk), and over 20,000 (will be dropped after compaction). A skill in the Fail band does not break the install; it breaks after the first session compaction. Treat it as urgent even though the immediate install looks clean.
- **Version sync failures (Check 8) ship the wrong label to users.** A mismatch between `plugin.json` version and `marketplace.json` version is cosmetic in terms of runtime behavior, but it means the version shown in `/plugin list` does not match what is actually installed. Fix it at commit time, not after.

## How it improves your workflow

`/validate-marketplace` is the last gate before a plugin change becomes someone else's problem. Every class of error it checks has a concrete failure mode — a broken install, a silent preload drop, a skill that disappears after compaction — and every check produces an actionable failure payload rather than a vague "something is wrong." Running it before every plugin commit means these failures are caught in your environment, on your timeline, with all the context needed to fix them. Wiring it into a pre-commit hook or CI step means it runs automatically and the check never gets skipped under deadline pressure.

## Related

- [`/entropy-scan`](entropy-scan.md) — drift audit (documentation accuracy); distinct from validate-marketplace's correctness focus; entropy-scan reports what has drifted, validate-marketplace reports what will fail at install
- [`/docs-maintenance`](docs-maintenance.md) — project Markdown quality; validate-marketplace covers plugin-specific JSON and frontmatter
- [`/ssl-audit`](ssl-audit.md) — SSL overlay frontmatter coverage; validate-marketplace checks frontmatter schema correctness, ssl-audit checks SSL field presence specifically
- [`/policies-list`](policies-list.md) — policy enforcement inventory; validate-marketplace Check 5 ensures the hooks.json that wires those policies parses correctly
- [Architecture](../../architecture.md) — where marketplace registration and plugin correctness fit in the 8-component harness model
