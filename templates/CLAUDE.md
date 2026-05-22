# Project Instructions

## Code Navigation

When tracing where a symbol is defined or finding all references to it, use LSP (goToDefinition, findReferences, hover) instead of Grep. LSP gives exact results; Grep gives text matches.

Use Grep/Glob for discovery (finding files, searching patterns). Use LSP for understanding (definitions, references, type info).

After locating a file with Grep/Glob, use LSP to navigate within it rather than reading the whole file.

## Forge Studio Workflow (use when installed)

For any non-trivial task (3+ steps, 5+ files, architectural decision, feature build), drive the work through the marketplace's agentic pipeline rather than editing directly:

1. **Plan.** Dispatch the planner subagent via the `Agent` tool with `subagent_type: agents:planner`. It writes `.claude/plans/s<N>-<slug>.md` containing `## Contract` (testable criteria) + `### Tasks` (`#### T1`, `#### T2`, …). Never edit source during planning.
2. **Spec.** Run `/living-spec` to initialize `.claude/spec.md` from the contract. Subagents share this as source of truth.
3. **Orchestrate.** Run `/orchestrate pipeline`. Per `T<n>`, it runs `/contract` → generator → reviewer → `/verify` internally. `/contract` re-reads success criteria from disk each turn (defeats context decay); `/verify` is the per-task evidence gate. Stops on first failure — the user decides whether to fix and resume.
4. **Reflect or postmortem.** `/reflect` on green, `/postmortem` on red. Captures the lesson outside the session.
5. **Progress log.** `/progress-log` before `/clear` or compact, so the next session resumes cleanly.

Single-line edits, typos, and conversational follow-ups skip this — direct work is faster. The `route-prompt.sh` hook classifies and suggests the right pattern; follow the nudge.

For batch same-op work across many files: `/fan-out`. For test-first work: `/tdd-loop`. To override the auto-router: `/orchestrate <pattern>`.

## Workflow

- Plan mode for non-trivial tasks (3+ steps or architectural decisions)
- Subagents for research and exploration (keep main context clean)
- For tasks touching >5 independent files, launch parallel sub-agents (5-8 files per agent). Use worktree isolation for independent parallel work on the same repo.

## Engineering Principles

- Trust your types. Don't add defensive checks the type system covers.
- Test behavior, not implementation. Minimize mocking.
- When renaming: search direct calls, type references, string literals, dynamic imports, re-exports, test files. Assume grep missed something.

## Useful Shortcuts

- Focus View (`Ctrl+O`): condensed view — scan long sessions fast
- Resume by name: `claude --resume "session title"`

## GitHub

Use the `gh` CLI for all GitHub operations.
