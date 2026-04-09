---
name: trace-evolve
description: Analyze execution traces to cluster failure patterns and propose harness improvements (rules, hooks, skills)
disable-model-invocation: true
---

# Trace Evolve

Periodic harness evolution skill. Run weekly or when you suspect recurring patterns.

**This skill analyzes and proposes only. It does NOT modify harness files.**

## Process

### Phase 1: Progressive Trace Loading

Use the three-view pattern (VCC paper, arXiv 2603.29678) to avoid loading raw JSONL directly:

1. **Check for compiled views**: `ls ~/.claude/traces/*-summary.md` — if recent summaries exist, start there
2. **If no summaries**: Run `/trace-compile` first, then return here
3. **Read summary views** for session orientation (most recent 2 weeks)
4. **Read error views** for failure patterns
5. **Follow specific entries** to full JSONL only when root cause needs raw context

### Phase 2: Failure Categorization

Categorize each failure using IDE-Bench's taxonomy (arXiv 2601.20886):

| Category | Signal | IDE-Bench Frequency |
|----------|--------|-------------------|
| **Premature editing** | Edit before sufficient reads/searches | 63% of failures |
| **Thrashing** | Same file edited 5+ times, oscillating regions | 28.2% of failures |
| **Context loss** | Re-reading already-read files, contradicting earlier conclusions | 27.6% of failures |
| **Specification compliance** | Tests fail on formatting, ordering, edge cases — not core logic | Variable |
| **Tool misuse** | Same command pattern fails repeatedly | Variable |
| **Environment** | Missing binary, wrong path, permission issues | Variable |

Prioritize by: `total_failures` (high) and `sessions_affected` (high).

### Phase 3: Propose Single-Variable Changes

For each cluster (top 5 max), propose ONE change (VeRO paper: single-variable changes prevent regression):

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
