# Zoom Out

`/zoom-out` steps back from the current file or function and returns a one-screen map of the relevant modules, callers, and the layer above the code you are looking at. It belongs to the `workflow` plugin. When you are unfamiliar with a section of code, trying to understand where something fits before reading it deeply, or planning a refactor that may have non-obvious callers, this skill gives you the orientation pass you need before diving in.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/zoom-out
```

No arguments. The skill operates on the current context — the file or function you have most recently been reading or editing.

## Why you need it

Reading a function in isolation misses its context. A function that looks safe to change may be called from three different layers with different invariants. A module that appears standalone may be a dependency of a hook that fires on every prompt. Without the higher-level map, you make local decisions that break non-local constraints.

`/zoom-out` is the orientation pass that precedes deep reading. Rather than reading files bottom-up until you find the entry point, it surfaces the call-graph context — relevant modules, callers, the layer above the current file — in a single screen. That map is the frame you need to make safe decisions about what a change will actually affect.

## When to use it

- Before reading deep into unfamiliar code in a new area — get the map first, then read the specifics.
- When planning a refactor that changes a function signature, a module interface, or a hook's behavior — find the callers before you move the code.
- When onboarding to a new codebase and trying to understand the layer structure before committing to a reading strategy.

Do not use it for narrow line-level questions — reading the file directly or using grep is faster and cheaper when you already know where you are. `/zoom-out` is for orientation, not lookup.

## Best practices

- **Run it before the first deep read in an unfamiliar area.** The map is cheapest when you have not yet read a lot — it orients the subsequent reads so they are purposeful rather than exploratory.
- **Use the caller list to scope refactors.** If `/zoom-out` surfaces three callers you did not know about, your refactor scope just expanded. Adjust the plan before writing code, not after discovering the callers in a broken build.
- **Combine with the MCP graph tools for large codebases.** The `codegraph` MCP server can answer caller/callee questions with exact structural context. Use `/zoom-out` for the first orientation pass; use `codegraph_callers` or `codegraph_impact` when you need precise references for a specific symbol.
- **One level up at a time.** If the map returned is still too close to the detail, run `/zoom-out` again. Each pass goes up one layer of abstraction.

## How it improves your workflow

`/zoom-out` is a small habit that prevents a large class of mistakes. The most common cause of a well-intentioned change breaking something unexpected is that the implementer did not know who called the thing they changed. By making the orientation pass explicit — a single command before any deep reading — `/zoom-out` ensures that you always have the caller context before you touch the code. The resulting changes are better scoped, the refactors are safer, and the onboarding time for unfamiliar sections drops significantly because you are reading purposefully rather than exploring randomly.

## Related

- [`../behavioral-core/scope.md`](../behavioral-core/scope.md) — after zooming out you often want to define an allowlist before proceeding; `/scope` does that
- [Architecture](../../architecture.md) — understanding the harness layer structure before navigating it
