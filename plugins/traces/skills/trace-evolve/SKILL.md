---
name: trace-evolve
description: Analyze execution traces to cluster failure patterns and propose harness improvements (rules, hooks, skills)
disable-model-invocation: true
---

# Trace Evolve

Periodic harness evolution skill inspired by NeoSigma's self-improving loop (39.3% improvement from failure mining + clustering + gated changes). Run weekly or when you suspect recurring patterns.

**This skill analyzes and proposes only. It does NOT modify harness files.**

## Process

### Phase 1: Failure Mining

1. **Read recent traces**: `ls -t ~/.claude/traces/*.jsonl | head -14` (last ~2 weeks)
2. **Extract failures**: Filter for entries where `exit_code != "0"` or output contains error keywords (`Error`, `Exception`, `FATAL`, `failed`, `denied`, `not found`)
3. **Build failure records**: For each failure, extract:
   - Command or file operation
   - Error message (from output_preview)
   - Working directory (context)
   - Timestamp (for frequency analysis)

### Phase 2: Failure Clustering

Group failures by **root cause mechanism**, not individual error messages:

| Cluster Type | Signal | Example |
|-------------|--------|---------|
| Tool misuse | Same command pattern fails repeatedly | `git push` blocked 5 times |
| Stale context | Edit failures after many edits without reads | 3+ edit-without-read sequences |
| Environment | Missing binary or wrong path | `command not found` patterns |
| Test regression | Same test fails across sessions | `test_X` fails in 4/7 sessions |
| Permission | Blocked by hooks or denied by user | `BLOCKED:` in output |
| Workflow | Repeated manual corrections after agent actions | Reverts, re-dos |

Prioritize clusters by: `total_failures` (high) and `sessions_affected` (high).

### Phase 3: Propose Changes

For each cluster (top 5 max), propose ONE of:

- **New `rules.d/` rule** — if the failure is a behavioral pattern (agent keeps doing X when it shouldn't)
- **New hook condition** — if the failure could be caught/prevented at a tool-use boundary
- **Skill enhancement** — if the failure reveals a workflow gap
- **No change** — if it's environmental, one-off, or already addressed

For each proposal, include:
- What specifically to change
- Why this addresses the root cause (not just the symptom)
- Estimated token impact (rules.d/ additions cost ~30-50 chars/message)
- Risk of regression (could this break existing behavior?)

### Phase 4: Report

## Output Format

```markdown
## Harness Evolution Report

**Period:** [date range]
**Sessions analyzed:** N
**Total trace entries:** N
**Failures found:** N (N% error rate)

---

### Cluster 1: [descriptive name]
- **Type:** [tool misuse | stale context | environment | test regression | permission | workflow]
- **Frequency:** N occurrences across M sessions
- **Example traces:**
  ```
  [2-3 representative trace entries]
  ```
- **Root cause:** [mechanism explanation]
- **Proposed change:** [specific suggestion with file path]
- **Token impact:** [estimated additional chars/message if rules.d/ change]
- **Regression risk:** [low | medium | high] — [why]

### Cluster 2: ...

---

### Summary
| Metric | Value |
|--------|-------|
| Clusters found | N |
| Proposed rule changes | N |
| Proposed hook changes | N |
| Proposed skill changes | N |
| No action needed | N |

### Next Steps
- [prioritized list of what to implement first]
- [suggested re-analysis date]
```

## Guidelines

- **Don't propose changes for one-off failures.** Minimum 3 occurrences across 2+ sessions before clustering.
- **Don't propose removing existing rules/hooks.** This skill adds, not subtracts. Removal requires separate analysis.
- **Estimate token impact honestly.** Every rules.d/ addition costs tokens on every message. Only propose rules for patterns that cause real damage.
- **Distinguish harness failures from code failures.** A test failing because of a bug is not a harness issue. A test failing because the agent wrote code without reading the file first IS a harness issue.
