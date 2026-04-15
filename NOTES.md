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
- `SubagentStop` — ✅ Added to agents plugin (contract-check.sh)
- `TaskCompleted` — ✅ Added to evaluator plugin (task-completion-gate.sh)
- `Stop` — ✅ Added to evaluator plugin (verify-before-complete.sh)

### Hook Events — Ready to Implement
- `InstructionsLoaded` (v2.1.69) — validate rule integrity on instruction load/reload
- `CwdChanged` (v2.1.83) — inject context when changing directories
- `FileChanged` (v2.1.83) — detect external file modifications (`.env`, `composer.lock`)
- `PermissionDenied` (v2.1.89) — suggest alternative approaches on denied actions
- `Elicitation`/`ElicitationResult` (v2.1.76) — monitor MCP questions asked to user

### Implemented (v2.1.105)
- PreCompact blocking — `pre-compact-guard.sh` in context-engine. Blocks compaction when uncommitted changes have no handoff or tasks are in-progress. Sync hook (async can't block).
- EnterWorktree `path` parameter — documented in `parallel-power` skill. Switch into existing worktrees without creating new ones.
- Stale worktree auto-cleanup — documented in `parallel-power` skill. Squash-merged PR worktrees auto-removed.
- `/proactive` alias for `/loop` — documented in `parallel-power` skill.

### Changelog-Sourced Capabilities (v2.1.107)
- **Skill `effort` field** — Override effort level per skill invocation
- **Skill `paths` field** — Glob patterns for auto-activation based on files being edited
- **Skill `when_to_use` field** — Additional trigger context appended to description
- **Agent `skills` preloading** — Inject full skill content into subagent context at startup
- **Agent `memory` field** — Persistent cross-session memory per agent (`user`/`project`/`local`)
- **`prompt` hook type** — LLM-driven evaluation at hook points (expensive, use sparingly)
- **`asyncRewake` hook field** — Background hook that wakes Claude on exit 2
- **`TaskCompleted` event** — Trigger verification when task marked done
- **`SLASH_COMMAND_TOOL_CHAR_BUDGET`** — Configurable skill description budget (1% of context window)

### New Capabilities — Ready to Investigate
- **Background Monitors (v2.1.105)** — new top-level `monitors` manifest key. Declares persistent background processes that auto-arm at session start or skill invoke. Each stdout line becomes a notification. Unlike hooks (event-driven, fire-and-exit), monitors are long-running stream watchers. Potential uses: watch for external file changes (replaces need for `FileChanged` hook), monitor error rates in trace files, watch CI/build output. Documented in `docs/architecture.md`. No plugins currently use monitors — hooks cover all current event-driven needs.
- **Marketplace dependency auto-install (v2.1.105)** — plugins with dependencies now auto-install. If forge-studio plugins declare inter-plugin dependencies, they'll resolve automatically. Currently no plugins have explicit dependencies.

### allowManagedHooksOnly (v2.1.101)
Enterprise setting that restricts which hooks can run. Plugin hooks are silently skipped when enabled. Marketplace plugins should gracefully handle being blocked — hooks must not assume they always execute. Worth adding a diagnostic check: detect when hooks aren't firing and surface a warning.

### Subagent MCP Tool Inheritance (v2.1.101)
Fixed: subagents now inherit MCP tools from parent. Previously they didn't, which broke agent contracts that assumed MCP availability. The agents plugin's planner/generator/reviewer triad should work correctly with MCP tools now — verify sprint contracts don't need MCP-awareness updates.

### Bash Permission Hardening (v2.1.98)
Significant hardening of Bash permission checks: backslash-escaped flags, compound commands, env-var prefixes all now properly validated. The `PermissionDenied` hook event (v2.1.89, listed above) is more valuable now — when permission denials happen, they're more likely intentional security boundaries rather than false positives.

### Skill Frontmatter Opportunities
- `context: fork` + `agent: Explore` — for exploration skills (`/explore`, `/audit-context`)
- `!command` dynamic injection — for `/morning` (auto-inject git log, handoffs)
- `argument-hint` — for skills accepting `$ARGUMENTS` without hints
