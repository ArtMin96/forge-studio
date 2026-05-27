# SSL Audit

`/ssl-audit` checks every SKILL.md frontmatter in the repository for the SSL overlay fields — `scheduling`, `structural`, and `logical` — and reports how many skills carry each field, which skills are missing a measurable success criterion (`logical:`), and where the typed schema validator finds shape or source-grounding issues. Both the presence check and the typed validator are informational: a missing `logical:` is flagged, not refused. It belongs to the `diagnostics` plugin, which provides health-checking and quality-gate skills across the harness.

---

## Install

```bash
/plugin install diagnostics@forge-studio
```

```text
/ssl-audit
```

No arguments. The skill walks `plugins/*/skills/*/SKILL.md` from the repository root automatically.

## Why you need it

The SSL overlay — from the paper *Scheduling-Structural-Logical Representation for Agent Skills* (arXiv:2604.24026) — separates a skill's preconditions (`scheduling:`), its decomposition into major steps (`structural:`), and its measurable success criterion (`logical:`). When a skill has a `logical:` field, the model can verify after execution whether the success criterion was met. When that field is absent, completion is a judgment call, not a checkable fact.

Forge's existing `description` and `when_to_use` carry scheduling-like information, so retrofitting is opt-in rather than required. `/ssl-audit` exists so you can see the coverage gap — which skills have no measurable success criterion — and prioritize adding `logical:` to the highest-traffic ones first. It does not enforce the overlay; it surfaces the coverage picture so you can act on it deliberately.

## When to use it

- When planning to harden skill discovery or promote a plugin to a "production" tier, to know which skills still lack a measurable success criterion before the promotion.
- When `/entropy-scan` flags skill quality concerns and you want the focused SSL-specific report.
- After adding the SSL overlay to a batch of skills, to confirm the counts moved as expected.
- When writing a new SKILL.md and you want a quick check that the `logical:` field you just wrote is recognized by the typed validator.

Do not use it for marketplace registration or hook executability checks — those belong to [`/validate-marketplace`](validate-marketplace.md) and [`/entropy-scan`](entropy-scan.md). `/ssl-audit` scrutinizes only the SSL frontmatter fields; it has no view of whether the plugin is registered or the hooks are executable.

## Best practices

- **Prioritize high-traffic skills for `logical:` retrofitting.** The audit produces a list of every skill missing the field, but not all gaps are equally consequential. A skill that is invoked in every sprint benefits more from a measurable success criterion than one that runs once a quarter. Sort the missing-logical list by how often the skill appears in your workflows and add `logical:` there first.
- **Use the typed validator for shape and grounding checks.** `audit.sh` gives you a fast presence count; `validate.py` goes deeper and checks that `logical:` values describe an observable outcome rather than a vague intention. Use the typed validator when you are actively retrofitting skills.
- **Watch the routing/dispatch subsection first.** The audit calls out routing or dispatch skills missing `logical:` separately, because an unverified router scales unreliability fastest (arXiv:2605.26112 §4.3). An empty list there is the healthy result; any entry is higher-priority than an ordinary missing-`logical` gap.
- **Treat schema `INFO` messages as seeds, not errors.** The `0.1-draft` schema has closed-vocabulary enums for `actions`, `resources`, and `effects` that are seeds, not enforced contracts. Mismatches emit as `INFO`. You do not need to conform every field to those enums; the vocabulary will tighten in future schema versions.
- **Fix frontmatter delimiter issues first.** The skill's known failure modes include a SKILL.md missing its closing `---`. When a skill shows as missing all SSL fields, check the closing delimiter before assuming no fields have been added.

## How it improves your workflow

`/ssl-audit` gives you a measurable signal for skill quality that goes beyond "does the frontmatter parse?" Running it periodically gives you a coverage trend — the number of skills with a `logical:` field should grow as you retrofit high-traffic skills. That trend is evidence that the harness is getting more verifiable over time, and it tells you concretely how far along that process is. When combined with `/entropy-scan` (which delegates to this skill as a sub-check), you get skill-quality signals as a standard part of every drift report.

## Related

- [`/entropy-scan`](entropy-scan.md) — invokes ssl-audit for skill quality signals; run entropy-scan for the full harness sweep
- [`/validate-marketplace`](validate-marketplace.md) — SKILL.md frontmatter schema correctness (known official fields, name shape); ssl-audit is specific to SSL overlay fields
- [`/verify`](../evaluator/verify.md) — the `logical:` field it checks is what verify uses as a success criterion; adding logical makes verify more precise
- [Architecture](../../architecture.md) — where skill quality and the SSL overlay fit in the 8-component harness model
