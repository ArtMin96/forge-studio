# Unix Pipe

`/unix-pipe` is the reference guide for running Claude Code outside an interactive session — headless mode, stdin/stdout piping, structured output formats, and CI/CD integration patterns. It belongs to the `reference` plugin, which provides zero-cost, passive reference content surfaced inline whenever automation comes up.

---

## Install

```bash
/plugin install reference@forge-studio
```

```text
/unix-pipe
```

No arguments. The skill surfaces the full headless and piping reference inline without invoking a model.

## Why you need it

Claude Code follows Unix philosophy: it is composable with other tools. The `-p` flag turns it into a non-interactive command that reads from stdin, writes to stdout, and exits with a meaningful code. This makes it a first-class participant in shell pipelines, CI/CD gates, and npm script workflows — but only if you know the exact flags, output format options, and permission-mode settings required to wire it in safely.

Without this reference, the most common failure modes are missing `--permission-mode auto` in a CI context (which causes an interactive prompt to stall the job), choosing the wrong `--output-format` for a downstream consumer, or forgetting `--allowedTools` restrictions that prevent accidental writes in a review-only gate.

## When to use it

- When building a CI gate that uses Claude to review diffs, check lint errors, or generate commit messages.
- When composing Claude with other shell tools — piping `git diff` or a build log into a Claude invocation and capturing the result.
- When adding `ai:*` scripts to `package.json` or a `Makefile` for teammates to run without an interactive session.

Do not use it for in-session orchestration — that is `/orchestrate` and `/dispatch`, which coordinate work inside an active Claude Code session. `/unix-pipe` is specifically for automation that runs outside an interactive session.

## Best practices

- **Set `--permission-mode auto` in CI.** Without it, Claude prompts for permission on writes and stalls unattended jobs. Use `--allowedTools "Read,Grep,Glob"` for read-only gates to prevent any writes from happening at all.
- **Choose `stream-json` for real-time consumers.** When a downstream script needs to process output as it arrives rather than after the invocation finishes, `--output-format stream-json` streams newline-delimited JSON events. Plain `json` waits until completion.
- **Pipe input, not file paths.** `git diff --staged | claude -p '...'` is more composable than passing a filename because it works regardless of where the caller is running. Reserve file arguments for cases where the full working-tree context matters.
- **Use `--verbose` during development.** `--verbose` emits tool calls and reasoning to stderr, leaving stdout clean for the actual output. This makes it straightforward to debug a pipeline without polluting the captured result.
- **Keep CI prompts narrow.** A broad prompt in a CI gate is expensive and slow. Name the exact check — "review this diff for SQL injection" — rather than a general "review this diff."

## How it improves your workflow

`/unix-pipe` makes Claude a composable component rather than a closed tool. By documenting the exact flags and idioms for piping, output formatting, and CI integration, it opens up a class of automation that most users never reach because the setup friction is invisible. Once the patterns are in place — a `git diff` pipe for commit-message generation, an error-log pipe for root-cause analysis, a CI step for security review — the cost of that automation drops to near zero per use while the consistency benefit compounds across every future run.

## Related

- [`parallel-power.md`](parallel-power.md) — parallel execution patterns, including fan-out loops that call `claude -p` per item
- [`ultrathink.md`](ultrathink.md) — effort level reference; `--effort` flag is available in headless mode too
- [`../workflow/orchestrate.md`](../workflow/orchestrate.md) — in-session orchestration; the in-session counterpart to unix-pipe's out-of-session automation
- [Architecture](../../architecture.md) — execution traces and multi-agent decomposition in the 8-component harness model
