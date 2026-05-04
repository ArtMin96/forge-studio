---
name: trace-evolve
description: Analyze execution traces to cluster failure patterns and propose harness improvements (rules, hooks, skills).
when_to_use: Reach for this on a weekly cadence, when failures feel "the same as last time", or when you want trace-driven proposals rather than guesses. Requires compiled views — run `/trace-compile` first if summaries are absent. Do NOT use to apply changes — trace-evolve only proposes; the actual SEPL pipeline is `/evolve` → `/assess-proposal` → `/commit-proposal`.
disable-model-invocation: true
effort: xhigh
paths:
  - ".claude/traces/*.jsonl"
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

## Guidelines

- Minimum 3 occurrences across 2+ sessions before clustering
- Don't propose removing existing rules/hooks — additions only
- Estimate token impact honestly — every rules.d/ line costs tokens per message
- Distinguish harness failures from code bugs
- Use summary/error views first — don't load full JSONL unless needed
