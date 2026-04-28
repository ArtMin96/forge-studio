---
name: token-pipeline
description: Run the 5-stage Token Transformation Pipeline (TRAE §5.2.2) over the current session state — Collection, Ranking, Compression, Budgeting, Assembly. Emits a concrete next-action recommendation (/compact, /lean-claude-md, or /progress-log + fresh session) instead of a generic warning.
when_to_use: Fires automatically via track-context-pressure at ~65% pressure; invoke manually any time context feels heavy or auto-compact looks imminent. Do NOT use to run a holistic context audit before work starts — that's `/audit-context`; this skill is the in-flight pressure-relief decision.
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# /token-pipeline — Explicit Context Engineering Stages

Replace the "context is heavy" feeling with a structured report. TRAE §5.2.2 defines the pipeline:

1. **Collection** — what's in the context right now
2. **Ranking** — recency × relevance score per entry
3. **Compression** — what can be summarized / dropped
4. **Budgeting** — per-category token allocation
5. **Assembly** — concrete next action

## Process

### Stage 1 — Collection

Inventory the load. For each source, estimate size in lines / rough tokens:

| Source | Check |
|---|---|
| CLAUDE.md (root + home) | `wc -l CLAUDE.md ~/.claude/CLAUDE.md` |
| MCP instructions | Check `mcp-instruction-monitor.sh` log (context-engine) for current MCP context reminders |
| Memory index | `wc -l .claude/memory/MEMORY.md` if present |
| Plan + spec + features | `wc -l .claude/plans/*.md .claude/spec.md` and `jq length .claude/features.json` |
| Progress tail | `wc -l claude-progress.txt` |
| System reminders | Check `track-system-reminders.sh` log |

Print a table with line counts.

### Stage 2 — Ranking

For each source, score on two axes (1–5):

- **Recency** — was it added this session (5) vs pre-existing (1)
- **Relevance** — does it inform the current task?

Flag low-score + high-size entries as "Lost in the Middle" candidates.

### Stage 3 — Compression

For each source with score < 6 (low recency + low relevance):

- CLAUDE.md too long? → recommend `/lean-claude-md`
- Handoff/progress too old? → recommend appending a fresh `/progress-log` + `/compact`
- Plan has stale sections? → recommend trimming the plan
- Memory bloat? → recommend `/memory-index` (memory plugin)

### Stage 4 — Budgeting

Suggest a per-category cap (tokens):

| Category | Suggested cap |
|---|---|
| CLAUDE.md total | 3000 |
| Active plan | 2000 |
| Active spec | 2000 |
| Memory pointers | 500 |
| Progress tail (3 entries) | 1500 |
| Current turn work | remainder |

### Stage 5 — Assembly

Emit ONE concrete recommendation, chosen by highest expected payoff:

- If CLAUDE.md > cap → `/lean-claude-md`
- If no fresh progress entry AND commits made → `/progress-log` + `/compact`
- If memory has >30 topics and many old → `/memory-index` audit
- If plan + spec + features all fresh → `/compact` with preservation instructions
- If nothing else → suggest starting a fresh session after `/progress-log`

Print the recommendation in a boxed line so it's hard to miss.

## Integration

- **Triggered by:** `plugins/context-engine/hooks/track-context-pressure.sh` at P2 / S2 thresholds (≈65% pressure / ~15 exchanges).
- **Reads:** CLAUDE.md, MCP log, memory index, `.claude/plans/`, `.claude/spec.md`, `.claude/features.json`, `claude-progress.txt`.
- **Delegates to (recommended next actions):** `/compact`, `/lean-claude-md`, `/progress-log`, `/memory-index`.
- **Feeds:** `/rest-audit` Efficiency axis consumes this skill's recommendations.

## Failure Modes

- No .claude/ artifacts → still run; recommendation will lean toward `/lean-claude-md` if CLAUDE.md is the dominant load.
- `jq` unavailable → skip features.json stage; note in output.

## Do NOT

- Do not auto-run `/compact` or `/lean-claude-md`. The user should choose; this skill is advisory.
- Do not print CLAUDE.md contents or plan contents — just sizes and headings.
