---
name: paper-research
description: Use when the user names a paper PDF in `docs/papers/` and asks to research, audit, or apply its findings to this marketplace — produces a single research brief that grounds the paper's claims in the existing plugin/hook/skill/agent surface, prefers reuse before proposing new, and verifies every Claude Code CLI mechanic the paper touches against current docs.
when_to_use: "Reach for this when a user references a PDF in `docs/papers/` (by arXiv ID, filename, or topic) and wants its findings turned into improvement candidates for the marketplace — especially when the request implies 'check what's already there first', 'don't introduce duplicates', or 'verify against Claude Code docs before planning'. Do NOT use to execute changes — this skill writes a brief; planning and code edits come after. Do NOT use for unrelated codebase audits — use `/entropy-scan` for drift or `/manifest-analyze` for evolution-ledger reports instead."
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
  - WebFetch
---

Produce a single Markdown brief at `.claude/briefs/<arxiv-id>-<slug>.md` that grounds a paper's claims in the marketplace's actual surface — plugins, skills, hooks, agents, ledger fields, docs — so the user can drive planning afterward without a second discovery pass.

## Why this skill exists

Papers arrive in `docs/papers/` constantly. Each is a candidate signal for marketplace improvement, and the cost of acting on one without grounding is high: duplicate skills, hooks that don't wire to ledger fields anyone reads, doc edits that bump count headers but leave the prose describing the old behavior. The brief is the artifact that prevents those failure modes by separating *research and audit* from *planning and execution*.

The brief is read-only. No source edits, no plugin changes, no doc rewrites. The user reviews it and decides what to plan, what to skip, what to file as future work.

## Inputs

- A paper under `docs/papers/<arxiv-id>v<N>.pdf`. The user names it by arXiv ID, filename, or topic.
- `docs/papers/README.md` — the citation index. Read first to see which papers already drive what (cited / unreferenced / cited-but-not-stored).

## Scope filter — abort if out of scope

This marketplace targets the **Claude Code CLI** (hooks, skills, plugins, agents, slash commands, settings, MCP servers, statusline). Papers outside that boundary cannot drive marketplace improvements, so they do not produce a brief.

Read the abstract and introduction before doing any other work. Abort with a one-line message to the user — and do not write a brief — when the paper's primary subject is any of:

- The Claude API / Anthropic SDK / Managed Agents (server-side or library integration, not CLI)
- Model fine-tuning, RLHF, post-training, distillation, or pretraining methodology
- Pure benchmark/eval papers with no transferable harness or workflow mechanic
- Theoretical ML, capability evaluations, or alignment research without an agentic-harness application

A paper is in scope when it covers any of: agentic harness design, hook/tool orchestration, context engineering, skill/plugin authoring patterns, memory or session strategies, multi-agent decomposition, execution traces, verification gates, evolution/self-improvement boundaries, behavioral steering, or other mechanics that wire into a CLI-side surface.

When the boundary is unclear, surface the abstract to the user with one question — "this reads as <SDK / fine-tuning / harness>; proceed?" — instead of guessing.

## Execution Checklist

- [ ] Read `docs/papers/README.md` and locate the target paper's current status (cited / unreferenced / missing locally).
- [ ] Run the scope filter (above). Abort early if the paper is out of scope; do not continue down the checklist.
- [ ] Read the paper end-to-end including figures, graphs, and tables. Visuals often refine or contradict the headline claim — use the pdf skill (`document-skills:pdf`) when image content matters, not just text extraction.
- [ ] For every claim that may become a recommendation, note section and page so the brief can cite it.
- [ ] Refresh Claude Code CLI knowledge via context7 *before* mapping anything. Query `plugin:context7:context7` for the surfaces the paper touches — at minimum: **hooks** (events, matchers, exit codes), **skills** (frontmatter fields, progressive disclosure), **plugins** (manifest, marketplace entry), **agents** (subagent definitions), **slash commands**, **settings** (`settings.json`, permissions, env vars), **MCP servers**, **statusline**. Quote the doc title and section you relied on. Training data is stale; context7 is the ground truth for current CLI mechanics.
- [ ] Map the paper's concepts onto the marketplace's existing surface. For each concept, search across:
  - `plugins/*/skills/*/SKILL.md` for skills whose `name`, `description`, or body verbs overlap
  - `plugins/*/hooks/hooks.json` and `plugins/*/hooks/*.sh` for hook events and matchers
  - `plugins/*/agents/*.md` for agent definitions
  - `docs/architecture.md`, `docs/research.md`, per-plugin `README.md` and `POLICY.md` files
- [ ] For each improvement candidate, prefer reuse: name the existing component that already does part of the work before proposing anything new. If a new component is genuinely needed, state which event, ledger field, or sibling skill it wires into — never freestanding.
- [ ] Re-verify any Claude Code CLI mechanic the candidate touches against the context7 results from the earlier step. If the candidate proposes a mechanic the earlier query did not cover, issue an additional context7 query for it now and quote the source. Fall back to `WebFetch` against `https://docs.claude.com/en/docs/claude-code/...` only when context7 has no entry. Paper-shaped intuition is not enough.
- [ ] Treat practical docs (architecture.md sections, plugin READMEs that describe wiring or behavior, POLICY.md files) as the primary update surface. Count headers (`<N> plugins. <M> skills. <H> hooks.`) are a final sanity check, not the substance — track them in the *Drift sanity* section only.
- [ ] Write the brief to `.claude/briefs/<arxiv-id>-<slug>.md`. Do not edit any plugin, doc, or source file.

## Brief Structure

The brief uses this exact shape so downstream planning is mechanical:

```
# Paper Brief: <short title>
arXiv: <id>v<N> · brief written: <YYYY-MM-DD>
status before this brief: <cited | unreferenced | cited-but-not-stored>

## Paper summary
3–6 paragraphs covering the core claim, method, and findings. Include what the figures/graphs/tables add beyond the prose — name the figure number and the takeaway.

## Marketplace surface map
Components already touching this paper's domain. One bullet per matched component:
- `<path>` — <one-line: what it currently does>

State explicitly when no match exists ("no current marketplace component covers §X"). Empty maps are valid output.

## Improvement candidates
One ### subsection per candidate. Each subsection contains, in this order:

- **Source**: paper section/page or figure number
- **Existing reuse considered**: components from the surface map that were evaluated, including any rejected
- **Proposal**: one of `reuse-only`, `extend-existing`, `new-component` — with a one-sentence reason
- **Wiring**: concrete file paths and the hook events / ledger fields / sibling skills the change connects to. New skills name their parent plugin. New hooks name the event and the matcher.
- **Practical docs to update**: architecture.md section name, plugin README paragraph, POLICY.md if a controllability rule is touched, marketplace.json only if structurally required
- **Verification log**: every Claude Code mechanic checked, with a quoted line from the source (context7 doc title + section, or WebFetch URL)

## Drift sanity
Two-line maximum. Names any count header that will need updating if candidates land. Not the work — just the bookkeeping.
```

## Examples

### Example 1 — paper already cited

Input: `arXiv:2604.17025` (CAAF — already cited in `docs/papers/README.md` for the verification mandate and paired-prediction skill). User: "Re-research CAAF and see what we still don't apply."

Output (`.claude/briefs/2604.17025-caaf-residual.md`, abbreviated):
```
# Paper Brief: CAAF — residual application audit
arXiv: 2604.17025v3 · brief written: 2026-05-21
status before this brief: cited

## Paper summary
CAAF's verification mandate (p.39) is already wired via evaluator/hooks/auto-verify.sh.
Paired-prediction skill mirrors §6.2. Residual coverage gap appears around §7.4
(post-failure reflection cadence) — Figure 5 shows a 28% improvement when the
reflection step runs after every third failed verification, not every failure.

## Marketplace surface map
- plugins/evaluator/hooks/auto-verify.sh — implements §verification mandate
- plugins/evaluator/skills/prediction-audit/SKILL.md — implements §6.2 paired predictions
- plugins/workflow/skills/reflect/SKILL.md — closest existing match to §7.4 reflection
  but fires manually, not on a cadence

## Improvement candidates

### Candidate 1 — make reflect cadence-aware via existing manifest entries
- Source: §7.4 p.46, Figure 5
- Existing reuse considered: workflow/skills/reflect (manual today), forge-meta/change_manifest
  failure_pattern field
- Proposal: extend-existing — add a `reflect_due` flag derived from manifest failure_pattern
  count, no new skill
- Wiring: plugins/workflow/skills/reflect/SKILL.md body, .claude/evolution/change_manifest.jsonl
  (existing `failure_pattern` field), no hook changes
- Practical docs to update: docs/agentic-workflow.md §reflection cadence paragraph;
  plugins/workflow/README.md reflect-skill row
- Verification log: SKILL.md frontmatter `name`/`description`/`when_to_use` confirmed via
  context7 query "claude code skill frontmatter" — fields unchanged in current docs

## Drift sanity
No count changes if Candidate 1 lands (extends existing skill, no new components).
```

### Example 2 — unreferenced paper

Input: `arXiv:2603.03329v1.pdf` (listed in *Unreferenced* section of `docs/papers/README.md`). User: "Pick up 2603.03329 and see if there's anything we should be doing differently."

Output (`.claude/briefs/2603.03329-<slug>.md`): same shape as Example 1. The *Marketplace surface map* may be sparse or empty — when so, the brief states that explicitly and every candidate is evaluated against the absence of prior reuse rather than inventing a match.

## Known Failure Modes

- **Headline claim taken verbatim without checking the figure.** Tables and graphs often refine or invert the prose. Read visuals via the pdf skill before drafting candidates.
- **New skill proposed before searching `plugins/**/SKILL.md`.** The marketplace already has ~75 skills; the new-skill instinct usually misses an existing match. Search verbs, not exact phrases.
- **Claude Code mechanic assumed from the paper's vocabulary.** The paper may say "pre-tool hook" while current docs say `PreToolUse`; matcher syntax and exit-code semantics drift between releases. Verify every mechanic against context7 first — training data ages faster than CLI surfaces change.
- **Out-of-scope paper smuggled in.** Fine-tuning, SDK, or pretraining papers occasionally read as harness-relevant on a skim. Hit the scope filter on the abstract before the checklist; if it borderlines, ask the user rather than producing a brief that recommends untransferable mechanics.
- **Count drift treated as the work.** Bumping `<N> plugins.` in README without updating the paragraph that describes the new plugin is the failure mode this skill exists to prevent. Drift goes in its own short section, after the substance.
- **Brief turns into a plan.** Brief is read-only. If the user wants a plan file, hand the brief off and stop — planning is the next workflow step, not this one.
