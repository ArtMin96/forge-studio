# Forward Briefing

`/forward-briefing` reads the last five entries in `claude-progress.txt` and rewrites them as a forward-looking briefing in `.claude/forward-briefing.md`. Where the raw log records what was blocked or left unresolved, the briefing reframes each blocker as an open question and orders next steps oldest-first so the resuming session opens in a problem-solving posture instead of replaying a list of past failures. It belongs to the `long-session` plugin, which maintains durable artifacts for coherent multi-session work.

---

## Install

```bash
/plugin install long-session@forge-studio
```

```text
/forward-briefing
```

No arguments. The skill reads `claude-progress.txt` from the repo root and writes the derived artifact to `.claude/forward-briefing.md`.

## Why you need it

After several sessions of struggle — authentication keeps failing, a test stays flaky, a count refuses to reconcile — the `claude-progress.txt` log accumulates a front-load of negative framing: "Blockers: still failing", "Blockers: can't proceed", "Blockers: blocked again." When `surface-progress.sh` injects that tail at SessionStart, the context window opens already anchored to past failure rather than forward momentum.

The mechanism behind this skill comes from research on how accumulated history affects LLM reasoning: at a fixed prompt length, the *framing* of injected history shapes the opening posture of the response. The same facts written as "What would unblock X?" bias the session toward action, while "Blocked on X" bias it toward diagnosis and defense. `/forward-briefing` applies that content-shift idea to your progress log without touching the log itself — it is a regeneratable derived view, not an edit to the source.

## When to use it

- After a session ends with non-trivial `Blockers:` sections in the progress log, especially when multiple consecutive sessions have recorded the same or related blockers.
- When the SessionStart briefing feels heavy — opening the session by re-reading a string of failure entries and wanting the next session to start from a forward-looking position instead.
- As a cleanup step after `/progress-log` before running `/clear` or compacting context.

Do not use it for writing the progress log itself — that is `/progress-log`. Do not use it for a full session briefing that includes spec, features, and git state — that is `/session-resume`.

## Best practices

- **Run it after `/progress-log`, not instead of it.** The forward briefing is derived from the progress log; the log has to be written first. The correct order is: append the session outcome with `/progress-log`, then run `/forward-briefing` to produce the reframed view.
- **Let the stale-detection do its job.** `surface-progress.sh` compares the mtime of `forward-briefing.md` against `claude-progress.txt`. If the log was updated after the briefing was last generated, the hook falls back to the verbatim tail automatically. You do not need to re-run `/forward-briefing` after every log append — only when the blockers are substantive enough to be worth reframing.
- **Read the open-questions section before diving in.** The reframed blockers are an explicit agenda for the session start. If an open question has an obvious answer, resolve it before picking up implementation work — the forward briefing is a cue to ask, not a mandate to guess.
- **Delete the file to reset.** If the forward briefing has drifted from the real state of the project, simply delete `.claude/forward-briefing.md`. The next session will fall back to the raw progress tail, and you can regenerate a fresh briefing after the next `/progress-log` run.

## How it improves your workflow

A progress log that honestly records failures is valuable — it preserves what happened. But injecting that log verbatim at the start of every session compounds the framing across sessions. `/forward-briefing` splits the two concerns: the log stays append-only and honest, while the session-start injection uses a derived view that leads with what to do next and asks questions rather than restating what went wrong. The result is that sessions after a difficult stretch open ready to work rather than needing several turns to shake off the failure context.

## Related

- [`/progress-log`](progress-log.md) — writes the entries that `/forward-briefing` reads; always run first
- [`/session-resume`](session-resume.md) — the full on-demand briefing; forward-briefing feeds its session-start injection while session-resume handles the full read-side briefing
- [`../../architecture.md`](../../architecture.md) — context management in the harness model
