# Impact Trace

`/impact-trace` answers the question "if I change this symbol, what actually breaks?" by joining two views that neither alone can provide: the static caller graph from the `codegraph` MCP server, and recent execution traces from the session's JSONL trace files. It surfaces three disjoint sets — callers that are both statically reachable and runtime-exercised (the real blast radius), callers that are statically reachable but have not fired recently (dormant), and runtime hits that the static graph does not account for (likely dynamic dispatch). It belongs to the `code-graph` plugin, which integrates static analysis with execution traces for impact assessment.

---

## Install

```bash
/plugin install code-graph@forge-studio
```

```text
/impact-trace <symbol> [days]
```

`symbol` is a function, class, or method name — qualified form (`Class::method` or `module.func`) is more precise than a bare name. `days` sets the trace-window depth and defaults to 7.

## Why you need it

Static analysis tells you who could call a symbol. Execution traces tell you who actually called it recently. Both views are incomplete on their own: a refactor guided only by the static graph will miss callers that are dispatched dynamically (via reflection, plugin loaders, or hook scripts), while a decision based only on execution traces will miss callers that exist but happened not to fire during the observed window.

This gap has a practical cost. A function that looks safe to delete because it did not appear in recent traces may have three static callers that will break the next time they run. A function that appears in traces far more often than the graph predicts has dynamic dispatch sites that a static refactor will silently miss. `/impact-trace` makes both gaps visible before the change lands.

The `primary_recommendation` field in the output is designed to be directly actionable: it names the highest-risk finding for your stated intent and tells you whether to proceed, proceed with care, or stop and investigate dynamic dispatch first.

## When to use it

- Before refactoring a function that is called in multiple places, to confirm the actual blast radius and identify any dynamic dispatch that the static graph does not capture.
- Before deleting code that appears unused, to verify that absence from recent traces reflects genuine dormancy rather than a dispatch path the graph misses.
- When a regression appears after a refactor that looked safe, to check whether a `runtime_only` caller was the actual execution path that broke.

Do not use it for sequential failure attribution — that is [`/failure-attribute`](../traces/failure-attribute.md), which walks manifest entries to localize a regression. Do not use it as a substitute for `codegraph_impact` when you only need the static view. `/impact-trace` is the join of both views; call it when both matter.

## Best practices

- **Qualify the symbol name.** A bare name like `run` matches many nodes; `HookRunner::run` resolves to exactly one. If you pass a bare name, the skill canonicalizes it via semantic search and picks the highest-scored match — review the canonical FQN in the output before trusting the results.
- **Confirm the MCP server is healthy before running.** The skill requires `codegraph` to be responding. Run `bash plugins/code-graph/hooks/code-graph-healthcheck.sh` if you are unsure. Without the MCP, the static side cannot run and the skill will not produce a meaningful result.
- **Take `runtime_only` seriously.** When `runtime_only` is non-empty, the primary recommendation is a `WARN` — this is the highest-severity outcome. These are callers that exercised the symbol but are not in the static graph, which means the refactor will likely miss them. Manual confirmation is required before proceeding.
- **Widen the trace window for dormant-caller checks.** If `static_only` is large and `intersection` is empty, the default 7-day window may not cover infrequently-run paths. Re-run with a larger `days` value (30 or 90) before concluding the callers are genuinely safe to ignore.
- **Do not collapse `runtime_only` into "graph drift" without checking.** Genuine dynamic dispatch sites belong in `runtime_only` and require manual confirmation that the refactor covers them. Graph drift — the graph needing a rebuild — is one possible explanation, but not the only one.

## How it improves your workflow

`/impact-trace` converts refactoring from a best-effort static analysis exercise into an evidence-backed decision. The three-set output makes the blast radius legible: the intersection is what you must change, the static-only set is what you should verify before deleting, and the runtime-only set is what needs manual investigation before any refactor touches the symbol. The `primary_recommendation` field distills all three sets into a single actionable line, so the output is usable immediately rather than requiring manual interpretation.

## Related

- [`../traces/failure-attribute.md`](../traces/failure-attribute.md) — localizes a regression by walking manifest entries; use after a break, not before a refactor
- [`../traces/trace-stats.md`](../traces/trace-stats.md) — runtime-only view of trace data; use when you need execution statistics without the static join
- [Architecture](../../architecture.md) — execution traces and static analysis in the 8-component harness model
