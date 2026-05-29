---
name: impact-trace
description: Use when you need to answer "if I change <symbol>, what actually breaks?" — joins the static caller graph (codegraph MCP) with recent execution traces to separate code-reachable callers from runtime-exercised ones. Surfaces three sets: static-known-and-exercised (real blast radius), static-known-but-dormant (callable but unused this session), and runtime-only (called but not in graph — likely dynamic dispatch or graph drift).
when_to_use: Reach for this before refactoring a hot function, before deleting code that looks unused, or when a regression appears and you suspect dynamic dispatch evaded a static refactor. Pair with `codegraph_impact` for the structural view alone or `/trace-stats` for the runtime view alone. Do NOT use for sequential failure attribution — use `/failure-attribute` instead; impact-trace is forward-looking and symbol-scoped, not failure-localizing.
disable-model-invocation: true
argument-hint: <symbol> [days]
allowed-tools:
  - Read
  - Bash
  - Glob
scheduling: a symbol (function/class/method) is about to be refactored, deleted, or suspected as the regression source; the codegraph MCP server is healthy
structural:
  - Resolve symbol via `mcp__codegraph__codegraph_search` if not already canonical
  - Query `mcp__codegraph__codegraph_callers` for the static caller set
  - Grep ~/.claude/traces/*.jsonl for tool-input or error mentions of the symbol in the last N days (default 7)
  - Compute the three set differences and emit a structured report
logical: report lists three disjoint sets (static∩runtime, static-only, runtime-only) with counts; a primary recommendation names the highest-risk set for the user's stated intent
---

# /impact-trace — Static × Execution Dual-View

Static graphs say "who *could* call this." Execution traces say "who *actually* called this." Neither view alone is enough: a refactor based on the graph alone misses dynamic dispatch; a decision based on traces alone misses callers that exist but didn't fire this session. arXiv:2605.18747 §4.4: *"the deepest harness would integrate [static + execution] perspectives ... answering questions like 'which components are slow' (requires both call graphs and profiling data), 'does this refactoring break APIs that external code depends on' (requires both static analysis and dynamic testing)."*

This skill joins the two.

## Inputs

- `$ARGUMENTS` — `<symbol> [days]`. `symbol` is a function, class, or method name (qualified is better — `Class::method` or `module.func`). `days` is the trace-window depth (default 7).
- Prerequisite: `codegraph` MCP server is healthy. Run `bash plugins/code-graph/hooks/code-graph-healthcheck.sh` if unsure.

## Algorithm

1. **Canonicalize the symbol.** If `$ARGUMENTS` is a bare name (no `::` or `.`), invoke `mcp__codegraph__codegraph_search` with the name and pick the highest-scored match. Record the canonical FQN.
2. **Static side — query callers.** Invoke `mcp__codegraph__codegraph_callers` with the canonical symbol. Capture the caller node list as `STATIC_CALLERS`.
3. **Runtime side — grep traces.** Search per-cwd JSONL files at `~/.claude/traces/*-<md5-of-cwd:8>.jsonl` (the collector pattern from `traces/hooks/collect-failure-trace.sh:11-13`). Filter to last N days via `find -mtime -N`. For each match, extract `tool`, `timestamp`, and the line. Capture as `RUNTIME_HITS`. Cheap heuristic — symbol mentioned in stdout/error is "exercised."
4. **Resolve runtime hits to callers.** For each `RUNTIME_HIT`, walk back to the nearest tool invocation that produced it (file path or command). Map to the calling node via `codegraph_search` on the file path.
5. **Emit three sets.**
   - `INTERSECTION` = static callers that also appear in runtime hits — these are the real blast radius.
   - `STATIC_ONLY` = static callers with zero runtime hits — callable but dormant this window.
   - `RUNTIME_ONLY` = runtime hits not resolvable to any static caller — likely dynamic dispatch, reflection, or graph drift (graph rebuild may be due).

## Output

```json
{
  "symbol": "Class::method",
  "window_days": 7,
  "static_callers_n": <int>,
  "runtime_hits_n": <int>,
  "intersection": [{"caller": "...", "trace_hits": <int>}],
  "static_only": [{"caller": "..."}],
  "runtime_only": [{"trace": "<path:line>", "ts": "..."}],
  "primary_recommendation": "<one line — see below>"
}
```

`primary_recommendation` is the highest-priority finding for the user's intent:
- If `runtime_only` is non-empty: `"WARN: <N> runtime hits not in static graph — dynamic dispatch or graph drift. Refactor will likely miss these."`
- Else if `intersection` is non-empty and >5: `"HIGH BLAST RADIUS: <N> callers actually exercise this symbol in last <D>d. Refactor with care; touch all listed callers in same PR."`
- Else if `intersection` is empty but `static_only` is large: `"SAFE TO REFACTOR: static graph shows <N> callers but none fired in last <D>d — verify with a broader window before deleting."`
- Else: `"LOW IMPACT: <N> caller(s), <M> runtime hit(s) — proceed."`

## Execution Checklist

- [ ] Parse `$ARGUMENTS` into `SYMBOL` and `DAYS` (default 7)
- [ ] Confirm codegraph MCP is responding — `bash plugins/code-graph/hooks/code-graph-healthcheck.sh` exits 0
- [ ] Canonicalize SYMBOL via `mcp__codegraph__codegraph_search` if not qualified
- [ ] Query callers via `mcp__codegraph__codegraph_callers`
- [ ] Grep `~/.claude/traces/*-<dir-hash>.jsonl` files within the window for symbol mentions
- [ ] Compute intersection / static_only / runtime_only sets
- [ ] Emit the JSON report and set `primary_recommendation` per the rule table above

## Do NOT

- Do not infer caller sets without the MCP. The graph is the source of truth; grep approximations will mis-identify dynamic dispatch as missing-caller.
- Do not widen the trace window to mask `static_only` results. Dormant callers are real — the answer is to check git blame on the dormant set, not to broaden until something fires.
- Do not collapse `runtime_only` into "graph drift" without checking. Genuine dynamic-dispatch sites (reflection, plugin loaders, hook scripts) belong in `runtime_only` and require manual confirmation.
- Do not duplicate `/failure-attribute` or `codegraph_impact`. failure-attribute walks manifest entries to localize a regression; codegraph_impact is the static blast-radius view alone. impact-trace is the join — call it only when both views matter.

## Examples

### Example 1 — Safe refactor

Input: `/impact-trace ConfigLoader::parseYaml 30`

Output:
```json
{
  "symbol": "ConfigLoader::parseYaml",
  "window_days": 30,
  "static_callers_n": 3,
  "runtime_hits_n": 0,
  "intersection": [],
  "static_only": [
    {"caller": "ConfigLoader::loadFromFile"},
    {"caller": "ConfigLoader::loadFromString"},
    {"caller": "tests/ConfigLoaderTest::testParse"}
  ],
  "runtime_only": [],
  "primary_recommendation": "SAFE TO REFACTOR: static graph shows 3 callers but none fired in last 30d — verify with a broader window before deleting."
}
```

### Example 2 — Dynamic dispatch warning

Input: `/impact-trace HookRunner::run 7`

Output:
```json
{
  "symbol": "HookRunner::run",
  "window_days": 7,
  "static_callers_n": 1,
  "runtime_hits_n": 12,
  "intersection": [{"caller": "Application::bootstrap", "trace_hits": 2}],
  "static_only": [],
  "runtime_only": [
    {"trace": "2026-05-19-abc12345.jsonl:142", "ts": "2026-05-19T08:30Z"},
    {"trace": "2026-05-19-abc12345.jsonl:189", "ts": "2026-05-19T09:15Z"}
  ],
  "primary_recommendation": "WARN: 10 runtime hits not in static graph — dynamic dispatch or graph drift. Refactor will likely miss these."
}
```
