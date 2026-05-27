# Progress Log

`/progress-log` appends the current session's outcomes to `claude-progress.txt` at the repo root — a durable, append-only record of what was completed, what is still in progress, what is blocking, and what the next session should prioritize. It also emits a matching ledger entry to `.claude/lineage/ledger.jsonl` for unified audit. It belongs to the `long-session` plugin, which keeps work coherent across sessions, compactions, and subagents by maintaining a shared set of durable artifacts.

---

## Install

```bash
/plugin install long-session@forge-studio
```

```text
/progress-log auth-rewrite
```

The optional argument names the topic for this session's entry. Omitting it defaults the topic to `session`.

## Why you need it

A Claude Code session can span hours and dozens of turns. When it ends — whether through `/clear`, a compaction, or simply closing the terminal — that accumulated context disappears. Without a written record, the next session starts blind: no knowledge of what commits landed, what decisions were made, or what was explicitly left for later. This forces the agent to re-explore before it can act, costs tokens, and frequently misses things the prior session knew.

`/progress-log` writes down exactly what changed, in a format that `surface-progress.sh` can inject at the next SessionStart, `/session-resume` can replay on demand, and `/forward-briefing` can reframe into a forward-looking view. The log is append-only by design — past entries are never edited, only new ones added — so it stays an honest audit trail. A companion hook `budget-trigger.sh` watches context-window usage and emits graduated advisories at 70%, 80%, 90%, and 99% consumed to surface the reminder before context is lost; you decide whether to invoke `/progress-log` when you see those signals.

## When to use it

- At session end, before closing the conversation or running `/clear`.
- Right before auto-compaction is about to fire — the budget trigger will warn you at 70–99% context usage.
- Whenever net-new commits land mid-session that the next session needs to know about, such as a completed feature that closes a contract criterion.

Do not use it for in-conversation task tracking — that is `TaskCreate` / `TaskUpdate`. Do not use it for per-commit changelog entries — those belong in the commit message. Do not run it when nothing changed in the session (no commits, no new blockers, no decisions worth recording).

## Best practices

- **Name the topic.** Passing a topic like `/progress-log auth-rewrite` or `/progress-log marketplace-sync` makes the log scannable across sessions. Generic entries all labeled `session` are harder to skim when you're looking for when a specific piece of work completed.
- **Record blockers honestly.** A blocker entry is not a failure; it is the most actionable part of the log. The next session — and `/forward-briefing` — uses it to surface what needs resolution before work can continue. Omitting blockers means the next session rediscovers them.
- **One entry per session, not per commit.** The log is a session-level record, not a commit log. If three commits land in one session, they all belong in one entry's `Done:` section. The ledger entry links back to the git state; you do not need to duplicate commit-level detail.
- **Never edit past entries.** The append-only invariant is intentional. If a prior entry recorded something incorrectly, add a correction entry — do not rewrite history. Tools that consume the log (`surface-progress.sh`, `/session-resume`) depend on the entries being stable once written.

## How it improves your workflow

The typical failure mode of long sessions is invisible state: work that completed but wasn't recorded, decisions that were made but only in the agent's context window, blockers that were forgotten before the next session started. `/progress-log` converts ephemeral context into a durable file that outlives any individual session. When combined with `init.sh` and `.claude/features.json`, it is the third piece of Anthropic's long-running agent pattern: the environment is reproducible, the requirements are structured, and the session history is written down. Every session that ends with a progress entry is a session the next one can pick up from without re-exploration.

## Related

- [`/session-resume`](session-resume.md) — replays the progress log along with spec and features to produce a full session briefing
- [`/forward-briefing`](forward-briefing.md) — reframes the progress log's blockers as open questions for a fresh-start posture
- [`/feature-list`](feature-list.md) — expands the plan contract into `.claude/features.json`; pairs with the progress log as the two halves of the durable session record
- [`../../architecture.md`](../../architecture.md) — context management and the long-session artifact pattern in the harness model
