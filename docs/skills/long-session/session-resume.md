# Session Resume

`/session-resume` reads the three long-session artifacts — `claude-progress.txt`, `.claude/spec.md`, and `.claude/features.json` — and emits a structured briefing so work can continue from exactly where the last session left off. It checks for `init.sh` at the repo root, shows the last three progress entries verbatim, summarizes feature statuses, tails the living spec, captures the current git state, and detects the test command for the stack, all in one pass. It belongs to the `long-session` plugin, which keeps work coherent across sessions, compactions, and subagents.

---

## Install

```bash
/plugin install long-session@forge-studio
```

```text
/session-resume
```

No arguments. The skill reads all available artifacts from disk and produces the briefing in a fixed shape ending with `Ready. What's next?`

## Why you need it

When a new session starts with no context — after a `/clear`, after an overnight gap, after a compaction — the agent is functionally amnesiac. It can read the codebase again, but it cannot know what decision was made two sessions ago about a disputed approach, which features are half-done, what the spec says about an edge case, or what the last session explicitly flagged as the next priority. Re-discovering all of that costs turns and frequently produces an inconsistent picture compared to what was actually agreed.

`/session-resume` assembles the full picture in one invocation. Where `surface-progress.sh` provides a lightweight preview injected automatically at SessionStart, `/session-resume` is the on-demand version that reads deeper — showing three entries instead of one, pulling the spec tail, listing in-progress feature items by name, and giving you the git state and test command so you can immediately verify environment and coverage. It is read-only and writes nothing; running it has no side effects.

## When to use it

- At the start of any new session to orient before picking up implementation work.
- Immediately after a `/compact` when the context window has been compacted and the in-session state is lost.
- When the automatic SessionStart preview from `surface-progress.sh` isn't enough detail and you need the full picture from all three artifacts.

Do not use it for writing resume artifacts — use `/progress-log` for the progress record and `/feature-list` for the requirements file. `/session-resume` is the read-side briefer only.

## Best practices

- **Run it before asking any implementation questions.** The briefing takes one turn; re-discovering the same state through ad-hoc questions takes many. Run `/session-resume` first, then ask the specific thing you need.
- **Follow the `init.sh` reminder.** If the skill reports that `init.sh` is present, run `bash init.sh` before writing any code. Tests and the dev server may not behave correctly on a partially-set-up environment, and the skill explicitly surfaces the reminder for this reason.
- **Use the features summary as your work queue.** The `N pending · M in_progress · K done` summary and the list of in-progress item descriptions tell you exactly where the pipeline expects work to continue. If the features file shows items `in_progress`, those are the natural first tasks for the session.
- **Cross-reference the spec tail with the progress.** The spec tail shows what the living spec says is in scope; the progress entries show what has actually been done. If they diverge, the divergence is worth resolving before generating more code.

## How it improves your workflow

The long-session plugin's value depends entirely on the artifacts being readable. `init.sh` is only useful if someone checks for it; `features.json` is only useful if someone summarizes its status; the progress log is only useful if someone surfaces the most recent entries. `/session-resume` is the single command that does all of that in one pass and formats the result as an actionable briefing. It converts the plugin's artifact collection from files you have to remember to read into a coherent start-of-session ritual that takes one command and fifteen seconds.

## Related

- [`/progress-log`](progress-log.md) — writes the entries that `/session-resume` reads; run at session end
- [`/feature-list`](feature-list.md) — produces `.claude/features.json` that `/session-resume` summarizes
- [`/forward-briefing`](forward-briefing.md) — produces a reframed view of the progress log's blockers; feeds the automatic SessionStart injection that `/session-resume` supplements on demand
- [`/init-sh`](init-sh.md) — produces the `init.sh` that `/session-resume` detects and surfaces
- [`../../architecture.md`](../../architecture.md) — the long-session artifact pattern in the harness model
