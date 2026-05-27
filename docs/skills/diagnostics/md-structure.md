# MD Structure

`/md-structure` audits a CLAUDE.md file against the four sections Karpathy's failure-mode analysis maps to: Think Before Coding, Simplicity First, Surgical Changes, and Goal-Driven Execution. For each section it reports PRESENT, WEAK, or MISSING with the file and line number, so you know exactly what is solid and what needs strengthening. It can also scaffold a fresh CLAUDE.md in the four-section shape when starting from scratch. It belongs to the `diagnostics` plugin, which provides health-checking and quality-gate skills across the harness.

---

## Install

```bash
/plugin install diagnostics@forge-studio
```

```text
/md-structure
/md-structure ./plugins/my-plugin/CLAUDE.md
```

The argument is the path to the CLAUDE.md to audit. It defaults to `./CLAUDE.md` when omitted.

## Why you need it

A CLAUDE.md that lacks actionable structure produces worse sessions: the model cannot reliably surface assumptions (no Think Before Coding section), tends toward speculative changes (no Simplicity First rule), touches files beyond the request (no Surgical Changes fence), and never defines what "done" means (no Goal-Driven Execution criterion). These are not abstract risks — they are the four failure modes Karpathy's analysis identifies as most common in LLM coding assistants.

`/md-structure` makes the gap visible without requiring you to memorize the four section names or manually scan the file. WEAK is meaningful too: a heading that exists but only says "be careful" is not an actionable rule, and the audit tells you which section has that problem and where it sits in the file so you can write a real rule to replace it.

## When to use it

- When authoring a new CLAUDE.md for a project or plugin that does not have one yet — run in scaffold mode to get the four-section starter document.
- When reviewing an existing CLAUDE.md against the four sections before a release or code review.
- When `/entropy-scan` invokes this as Check 9b and you want to see the full audit output directly.
- After a significant edit to CLAUDE.md, to confirm the structure is still intact.

Do not use it for deleting or compressing lines — size reduction belongs to `/lean-md` (context-engine plugin). `/md-structure` answers "is the architecture right?", not "is it too big?". Run both for a complete picture.

## Best practices

- **Treat WEAK as a blocking finding.** A section that exists but lacks a concrete actionable rule is worse than a missing section: it creates a false sense that the constraint is covered when it is not. Rewrite WEAK sections to include a specific rule with a concrete example.
- **Use the scaffold as a starting point, not a final document.** The four-section starter the skill emits is minimal by design. Fill in project-specific rules before treating the scaffold as production-ready.
- **Audit the root CLAUDE.md and plugin-specific ones separately.** The skill audits only the path passed in; it does not glob all CLAUDE.md files. If you have per-plugin CLAUDE.md files, run the audit on each one individually.
- **Pair with `/lean-md` after setting structure.** Once the four sections are PRESENT and each has an actionable rule, run `/lean-md` to trim any prose that exceeds the context budget without weakening the rules.
- **Run before a new sprint.** A CLAUDE.md with MISSING Goal-Driven Execution means the session has no verifiable done-criteria — every task in the sprint is harder to verify as complete.

## How it improves your workflow

`/md-structure` gives you a fast, repeatable signal that your behavioral instructions are architecturally sound. The PRESENT / WEAK / MISSING report takes seconds to read and immediately tells you where the gaps are — no manual scanning required. Pairing this audit with `/lean-md` (for size) and `/rules-audit` (for runtime compliance) gives you a three-layer CLAUDE.md health check: structure, size, and adherence.

## Related

- [`/entropy-scan`](entropy-scan.md) — invokes md-structure as Check 9b; run entropy-scan for the full harness sweep, md-structure directly for a focused CLAUDE.md audit
- [`/docs-maintenance`](docs-maintenance.md) — covers the full project doc tree; md-structure focuses specifically on CLAUDE.md structure
- [`/rules-audit`](../behavioral-core/rules-audit.md) — audits runtime rule compliance; md-structure checks that the rules are structurally present to be audited
- [Architecture](../../architecture.md) — where behavioral steering and CLAUDE.md structure fit in the 8-component harness model
