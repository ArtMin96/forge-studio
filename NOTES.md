# Notes

## TODO

- [ ] Investigate bypass permissions API call impact on token budget
- [ ] Check: https://x.com/Hesamation/status/2038997792962597138
- [ ] Check: https://x.com/iamfakeguru/status/2038965567269249484
- [ ] Check: https://x.com/neural_avb/status/2038982104445538595

## Future Investigations

### VCC Binary Trace Compiler
Full compiler (lex → parse → line-assign → view-lower) for raw Claude Code JSONL traces. Would ship as `bin/` executable via plugin. Currently overkill for typical trace volume — skill-based `/trace-compile` covers the need. Revisit when trace volume justifies it.
- Paper: arXiv 2603.29678
- Reference implementation: Python, ~1000 LOC

### Eval Framework for Harness Hill-Climbing
LangChain's 6-step eval-driven optimization loop: source evals → tag by category → train/holdout split → baseline → optimize → validate. Requires meaningful production trace volume to produce signal. The `/trace-evolve` skill is the manual seed of this loop.
- Blog: https://blog.langchain.com/better-harness-a-recipe-for-harness-hill-climbing-with-evals/
- Implementation: deepagents repository

### Wiki Memory Architecture
Karpathy's LLM Wiki pattern: three-layer compounding knowledge (Raw Sources → Wiki → Schema). Operations: Ingest (process new sources into wiki), Query (search wiki, file answers back), Lint (health-check for contradictions, stale claims, orphans). Would require rearchitecting the memory plugin from three-tier index/topics/transcripts to a wiki-with-cross-references model.
- Gist: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
- Claude Code extension: https://github.com/kfchou/wiki-skills

### HTTP Hooks for External Integrations
Hook type `"type": "http"` (v2.1.63) POSTs JSON to URLs. Enables webhook integrations for trace collection, notifications, CI triggers. Requires external infrastructure — out of scope for local-first marketplace.

### Hook Events — Implemented
- `PostToolUseFailure` — ✅ Added to traces plugin (collect-failure-trace.sh)
- `StopFailure` (v2.1.78) — ✅ Added to traces plugin (log-stop-failure.sh)

### Hook Events — Ready to Implement
- `CwdChanged` (v2.1.83) — inject context when changing directories
- `FileChanged` (v2.1.83) — detect external file modifications (`.env`, `composer.lock`)
- `SubagentStop` (v2.1.71) — verify agent output meets contract requirements
- `PermissionDenied` (v2.1.89) — suggest alternative approaches on denied actions
- `Elicitation`/`ElicitationResult` (v2.1.76) — monitor MCP questions asked to user

### Skill Frontmatter Opportunities
- `context: fork` + `agent: Explore` — for exploration skills (`/explore`, `/audit-context`)
- `!command` dynamic injection — for `/morning` (auto-inject git log, handoffs)
- `argument-hint` — for skills accepting `$ARGUMENTS` without hints
