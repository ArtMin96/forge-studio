# Ultrathink

`/ultrathink` is the reference guide for Claude's reasoning effort levels. It explains what each level does, what the cost/quality tradeoff looks like at each setting, and when a given task shape warrants deep thinking versus a lightweight response. It belongs to the `reference` plugin, which provides zero-cost, passive reference content surfaced inline during the session.

---

## Install

```bash
/plugin install reference@forge-studio
```

```text
/ultrathink
```

No arguments. The skill emits the effort-level reference table and guidance inline without invoking a model.

## Why you need it

Claude's effort levels (`low`, `medium`, `high`, `max`) are not cosmetic labels — they determine how much compute is spent on internal reasoning before an answer is produced. Using `max` effort on a file rename wastes tokens with no quality return; using `low` effort on a security architecture decision produces shallow analysis. The gap between picking the right level and picking the wrong one is measurable in both output quality and token cost.

Most users never change the effort level because they do not have a clear mental model of where each level pays off. `/ultrathink` makes that model explicit: a table of levels with their intended query shapes and relative cost, plus the `ultrathink` keyword shortcut for a one-off max-effort response without touching global settings.

## When to use it

- When choosing an `effort:` value for a new skill's frontmatter.
- Before a complex architectural decision, security analysis, or multi-step debugging session where you want maximum reasoning depth without resetting global effort for the session.
- When output quality has felt shallow and you want to understand whether a higher effort level would help.

Do not use it for changing the effort level mid-session — use the `/effort` command instead. `/ultrathink` is the explanation and reference; `/effort` is the switch.

## Best practices

- **Default to `high` for anything ambiguous.** The skill documents `high` as the default for a reason: it is the level where most development work produces the best quality-to-cost ratio. Reserve `max` for genuinely multi-step deductions.
- **Use the `ultrathink` keyword for one-offs.** Including the word "ultrathink" anywhere in a prompt triggers max-effort for that turn only, leaving the global setting unchanged. This is cheaper than a global `/effort max` when you need one deep response.
- **Match effort to query shape.** Simple file reads, straightforward renames, and standard CRUD operations do not need elevated effort — the skill's "When Deep Thinking Wastes Tokens" section is the guide for when to stay low.
- **Remember adaptive thinking.** On capable models, Claude scales internal reasoning dynamically within the selected level. An easy query at `high` effort still gets a direct response; the model does not pad reasoning to fill a budget.

## How it improves your workflow

`/ultrathink` converts effort selection from a vague intuition into a deliberate choice backed by a cost/quality model. Knowing that `max` effort is for multi-step deductions, that `high` is the productive default, and that the `ultrathink` keyword provides a zero-configuration escape hatch means effort is calibrated per task rather than set once and forgotten. The result is better responses on complex problems and fewer wasted tokens on trivial ones.

## Related

- [`parallel-power.md`](parallel-power.md) — reference for parallel execution patterns; pairs with effort selection when dispatching subagents
- [`unix-pipe.md`](unix-pipe.md) — headless usage patterns including effort flags in CI/CD contexts
- [Architecture](../../architecture.md) — context management and token efficiency in the 8-component harness model
