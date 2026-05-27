# Lean Agents

`/lean-agents` is a token optimization guide for multi-agent workflows. When subagent dispatches feel expensive — the token budget is tightening, per-turn cost is ballooning, or you are about to launch a large [`/fan-out`](fan-out.md) — it recommends a four-layer isolation profile that drops subagent overhead from roughly 50,000 tokens per turn down to around 5,000. It prints the recommended profile with concrete tool restrictions, context constraints, and model selections for each subagent role. It belongs to the `agents` plugin, which provides the multi-agent orchestration harness for Forge Studio. Because it only prints a recommendation and never touches source files, it runs entirely at zero model-invocation cost.

---

## Install

```bash
/plugin install agents@forge-studio
```

```text
/lean-agents
```

No arguments. Run it before launching any heavy fan-out or multi-stage pipeline, or after a run that cost more than expected to understand why.

## Why you need it

Every subagent starts life expensive. Before it does any actual work, it loads CLAUDE.md (10–18K tokens), MCP tool schemas (roughly 9K), agent definitions (3.3K), skills (2.6K), and a system prompt (3.5K) — totaling around 50,000 tokens of overhead per subagent, per turn. In a fan-out with five agents running three turns each, that overhead alone accounts for 750,000 tokens before a single line of code is read or written. Most of that load is irrelevant to what the subagent actually needs to do.

The core insight the skill captures is that each subagent builds its context from scratch. When the parent agent reads a file, the child gets zero benefit — it will re-read everything independently. Every token the child loads unnecessarily is wasted twice: once in the child's context and once in whatever the parent pays to receive the child's verbose result. Lean agents is the answer to the question of how much of that overhead is actually load-bearing for a given subagent role.

## When to use it

- Before launching any heavy [`/fan-out`](fan-out.md), [`/worktree-team`](worktree-team.md), or multi-stage pipeline where token cost is a concern.
- When diagnosing why a recent multi-agent run cost significantly more than expected.
- When designing a new subagent role and deciding which tools it actually needs versus which it inherits by default.

Do not use it for single-agent flows — the overhead it targets only exists when subagents are spawned. Direct execution in the main session is already as lean as it gets.

## Best practices

- **Match isolation level to subagent task, not to caution.** A grep-only exploration agent does not need Write, Edit, or Bash in its tool set — and loading those schemas costs tokens without enabling anything useful. Tool restriction is the first and cheapest layer to apply.
- **Write short, specific agent prompts.** Include file paths, line numbers, and exact instructions. Background context and project history belong in the parent's context, not in the prompt the child loads. Each word in the subagent prompt costs tokens in that subagent's context; information the child will not use is pure waste.
- **Tell agents what format to return results in.** A prompt that ends with "report in under 200 words" or "return only file paths and line numbers" prevents verbose results that bloat the parent's context window. Result compression (layer three) costs nothing and pays back at both ends of the call.
- **Use `CLAUDE_CODE_SIMPLE=1` for mechanical subagents.** For simple read-only or grep tasks, this environment variable reduces the system prompt from around 60,000 tokens to roughly 50 tokens. The trade-off is real: the agent loses all behavioral steering — no CLAUDE.md, no hooks, no skills. Use it only for subagents whose job is mechanical enough that behavioral steering would not change the outcome.
- **Pass short file contents directly in the prompt.** If a subagent needs the content of a file under 50 lines, include it in the prompt rather than having the agent re-read it. The re-read costs a tool call and loads the file schema; pasting the content costs only the characters.

## How it improves your workflow

Multi-agent orchestration is most valuable when the parallelism and isolation benefits outweigh the overhead cost. That trade-off tips in the wrong direction when subagents are loaded with context they do not need. `/lean-agents` makes the four levers for reducing that overhead — tool restriction, prompt minimization, result compression, and `CLAUDE_CODE_SIMPLE` — concrete and role-specific rather than abstract advice. The result is that a fan-out over ten files can cost a fraction of what it would cost with default subagent settings, which makes the parallelism benefit real rather than theoretical.

## Related

- [`fan-out.md`](fan-out.md) — the primary beneficiary of lean-agent profiles; apply `/lean-agents` before any large fan-out
- [`worktree-team.md`](worktree-team.md) — parallel isolated pipelines where per-role tool restriction is built into the CLAUDE.md composition step
- [`dispatch.md`](dispatch.md) — the routing layer that decides how many subagents to spawn; `/lean-agents` reduces the cost of each one
- [Architecture](../../architecture.md) — multi-agent decomposition in the 8-component harness model
