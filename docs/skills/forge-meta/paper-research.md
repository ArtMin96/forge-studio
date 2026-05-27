# Paper Research

`/paper-research` reads a paper PDF from `docs/papers/`, maps its findings onto the marketplace's existing surface, and writes a structured research brief — without touching any source file. It belongs to the `forge-meta` plugin, which manages Forge Studio's self-evolution boundary.

---

## Install

```bash
/plugin install forge-meta@forge-studio
```

```text
/paper-research 2604.17025
```

The argument is an arXiv ID, filename, or topic that identifies a PDF in `docs/papers/`. The skill locates the file, checks its current status in `docs/papers/README.md`, and writes a brief to `.claude/briefs/<arxiv-id>-<slug>.md`.

## Why you need it

Research papers arrive in `docs/papers/` as candidate signals for marketplace improvement, but acting on one without first grounding it is expensive: you can end up proposing skills that already exist under a different name, hooks that don't wire to any ledger field anyone reads, or doc changes that bump count headers while leaving the prose describing the old behavior. `/paper-research` prevents those failure modes by separating the research and audit step from planning and execution.

The brief is the artifact that makes planning mechanical. It maps every claim in the paper onto components already in the marketplace, evaluates whether each improvement needs a new component or just an extension of an existing one, and re-verifies every Claude Code CLI mechanic the paper touches against current docs via context7 — not from training data, which ages. When the brief is done, you have a grounded candidate list to hand off to the planner. The skill itself writes nothing but the brief.

## When to use it

- When a user references a PDF in `docs/papers/` by arXiv ID, filename, or topic and wants its findings turned into improvement candidates for the marketplace.
- When the request implies "check what's already there first" or "don't introduce duplicates" — the surface-map section of the brief is built exactly for this.
- When you want to verify that a paper's mechanics are still current before committing to a plan based on it.

Do not use it to execute changes — this skill writes a brief; planning and code edits come after. Do not use it for unrelated codebase audits — use [`/entropy-scan`](../diagnostics/entropy-scan.md) for drift or [`/manifest-analyze`](manifest-analyze.md) for evolution-ledger reports instead.

## Best practices

- **Hit the scope filter before reading deeply.** The skill has an explicit out-of-scope list: fine-tuning methodology, pure benchmark papers, Claude API / SDK integration, and theoretical ML without an agentic-harness application. Read the abstract first and abort early if the paper falls outside those boundaries rather than producing a brief that recommends untransferable mechanics.
- **Read visuals, not just prose.** Tables and graphs in papers often refine or contradict the headline claim. Use the pdf skill to surface figure content before drafting candidates — a finding only stated in a figure is still a finding.
- **Prefer reuse.** Search `plugins/*/skills/*/SKILL.md` for skills whose description or body verbs overlap before proposing anything new. The marketplace already has many skills; the instinct to add new components usually misses an existing match.
- **Verify every CLI mechanic against context7.** The paper may use vocabulary that has drifted from current Claude Code CLI docs. Query context7 for each mechanic the paper touches (hooks, skill frontmatter fields, agents, settings) and quote the source. Training data is stale; context7 is the ground truth.
- **Keep the brief read-only.** If the user asks you to plan or implement based on the brief, hand it off and stop. Planning is the next workflow step, not part of this skill.

## How it improves your workflow

`/paper-research` makes the gap between "there's a relevant paper" and "here's a grounded plan" much smaller. Without it, mapping a paper to the marketplace requires a manual discovery pass through plugins, hooks, docs, and CLI references — a process that is slow, easy to shortcut, and prone to proposing duplicates. The brief concentrates that work into a single structured artifact that names what already exists, what genuinely needs to change, and what CLI mechanics need verification. The planner that comes after has everything it needs in one place.

## Related

- [`/manifest-analyze`](manifest-analyze.md) — aggregate analysis of the evolution ledger; use for evolution-ledger reports rather than paper grounding
- [`../diagnostics/entropy-scan.md`](../diagnostics/entropy-scan.md) — codebase drift audit; use for structural drift rather than paper grounding
- [`/change-manifest`](change-manifest.md) — the ledger entry to write after implementing a candidate from the brief
- [Architecture](../../architecture.md) — where research-driven improvements fit in the 8-component harness model
