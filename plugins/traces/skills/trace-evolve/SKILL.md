---
name: trace-evolve
description: Analyze execution traces to cluster failure patterns and propose harness improvements (rules, hooks, skills).
when_to_use: Reach for this on a weekly cadence, when failures feel "the same as last time", or when you want trace-driven proposals rather than guesses. Requires compiled views — run `/trace-compile` first if summaries are absent. Do NOT use for applying changes — use `/evolve` → `/assess-proposal` → `/commit-proposal` instead; trace-evolve only proposes.
disable-model-invocation: true
effort: xhigh
paths:
  - ".claude/traces/*.jsonl"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Write
logical: proposal artifact written to .claude/lineage/proposals/ with cluster-derived rule / hook / skill suggestions
---

# Trace Evolve

Periodic harness evolution skill. Run weekly or when you suspect recurring patterns.

**This skill analyzes and proposes only. It does NOT modify harness files.**

## Process

### Phase 1: Progressive Trace Loading

Load structured views first so analysis doesn't drown in raw JSONL:

1. **Check for compiled views**: `ls ~/.claude/traces/*-summary.md` — if recent summaries exist, start there
2. **If no summaries**: Run `/trace-compile` first, then return here
3. **Read summary views** for session orientation (most recent 2 weeks)
4. **Read error views** for failure patterns
5. **Follow specific entries** to full JSONL only when root cause needs raw context

### Phase 2: Failure Categorization

Categorize each failure into one of the common failure shapes:

| Category | Signal | Typical Frequency |
|----------|--------|-------------------|
| **Premature editing** | Edit before sufficient reads/searches | Common |
| **Thrashing** | Same file edited 5+ times, oscillating regions | Common |
| **Context loss** | Re-reading already-read files, contradicting earlier conclusions | Common |
| **Specification compliance** | Tests fail on formatting, ordering, edge cases — not core logic | Variable |
| **Tool misuse** | Same command pattern fails repeatedly | Variable |
| **Environment** | Missing binary, wrong path, permission issues | Variable |

Prioritize by: `total_failures` (high) and `sessions_affected` (high).

### Phase 3: Propose Single-Variable Changes

For each cluster (top 5 max), propose ONE change — single-variable changes keep regression attribution possible:

- **New `rules.d/` rule** — if behavioral pattern (agent keeps doing X)
- **New hook condition** — if catchable at tool-use boundary
- **Skill enhancement** — if workflow gap
- **No change** — if environmental, one-off, or already addressed

For each proposal:
- What specifically to change
- Why this addresses root cause
- Token impact estimate (rules.d/ ~ 30-50 chars/message)
- Regression risk

### Phase 4: Report

```markdown
## Harness Evolution Report

**Period:** [date range]
**Sessions analyzed:** N
**Method:** [summary views | raw JSONL | mixed]

---

### Cluster 1: [name]
- **Category:** [premature editing | thrashing | context loss | spec compliance | tool misuse | environment]
- **Frequency:** N occurrences across M sessions
- **Example traces:** [2-3 representative entries]
- **Root cause:** [mechanism]
- **Proposed change:** [specific suggestion with file path]
- **Token impact:** [estimated]
- **Regression risk:** [low | medium | high] — [why]

---

### Summary
| Metric | Value |
|--------|-------|
| Clusters found | N |
| By category | premature editing: N, thrashing: N, context loss: N, other: N |
| Proposed changes | rules: N, hooks: N, skills: N, none: N |

### Next Steps
- [prioritized implementation list]
- [suggested re-analysis date]
```

## Execution Checklist

- [ ] Phase 1 — load compiled summary views; run `/trace-compile` first if absent
- [ ] Phase 2 — categorize each failure (premature editing / thrashing / context loss / spec compliance / tool misuse / environment), prioritize by total_failures and sessions_affected
- [ ] Phase 3 — for each top-5 cluster propose ONE single-variable change (rule / hook / skill / no-change) with token impact and regression risk
- [ ] Phase 4 — emit the markdown evolution report (Period, Sessions, Method, per-cluster sections, Summary table, Next Steps)

## Examples

Input: `~/.claude/traces/` contains summary views showing 7 sessions where Edit was called before any Read on the target file, total 14 occurrences across 5 sessions.

Output:
```markdown
### Cluster 1: premature editing on unread files
- **Category:** premature editing
- **Frequency:** 14 occurrences across 5 sessions
- **Example traces:** 2026-05-08-aa12, 2026-05-11-bb34, 2026-05-14-cc56
- **Root cause:** Edit issued before sufficient Read of the target region
- **Proposed change:** new `rules.d/read-before-edit.md` — "Read the target file region before issuing Edit; the Edit tool errors when state is stale anyway."
- **Token impact:** ~45 chars/message, ~12 tokens
- **Regression risk:** low — restates existing tool contract
```

Input: error views show `tsc --noEmit` failing 9 times across 3 sessions with "Cannot find module" after a rename refactor.

Output:
```markdown
### Cluster 2: rename refactors leave stale imports
- **Category:** specification compliance
- **Frequency:** 9 occurrences across 3 sessions
- **Example traces:** 2026-05-09-dd78, 2026-05-12-ee90, 2026-05-15-ff12
- **Root cause:** grep-driven rename misses dynamic imports and re-exports
- **Proposed change:** skill enhancement — add a post-rename verification step to `/skill-creator` or a new `refactor-verify` checklist invoking `tsc --noEmit` before commit.
- **Token impact:** none (skill-local)
- **Regression risk:** low — additive checklist
```

## Guidelines

- Minimum 3 occurrences across 2+ sessions before clustering
- Don't propose removing existing rules/hooks — additions only
- Estimate token impact honestly — every rules.d/ line costs tokens per message
- Distinguish harness failures from code bugs
- Use summary/error views first — don't load full JSONL unless needed
