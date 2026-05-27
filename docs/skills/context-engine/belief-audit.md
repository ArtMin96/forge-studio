# Belief-Audit

`/belief-audit` detects the gap between what Claude believes a file contains and what is actually on disk. After every Edit or Write, the `context-engine` plugin records a sha256 fingerprint of the changed file in `.claude/state/belief.jsonl`. When you invoke `/belief-audit`, it re-computes the sha256 for the N most recently edited files and compares the stored signatures against current disk state, emitting a drift report and exiting non-zero if any file has diverged. It belongs to the `context-engine` plugin, which provides context measurement, pressure management, and belief-state safety for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install context-engine@forge-studio
```

```text
/belief-audit        # check the 5 most-recently-edited files (default)
/belief-audit 10     # check the 10 most-recently-edited files
```

The optional numeric argument sets how many unique paths to inspect. The skill reads `.claude/state/belief.jsonl`, takes the latest snapshot per unique path, limits to N most-recent unique paths, and compares each against its current sha256 on disk.

## Why you need it

Context compaction is lossy. When a session's context window fills and compacts, a multi-line edit gets compressed to a one-line mention. Later in the same session — or in the next session — Claude reasons about "the current state" of a file from that compressed memory. If anything touched that file in the interval (another hook, a `git pull`, a parallel agent, or even a manual save), Claude's belief and disk reality have silently diverged.

The gap `|Bk − Sk|` between the agent's belief `Bk` and actual system state `Sk` is a primary root cause of brittleness in long-running agent sessions (arXiv:2605.18747 §4.3). An edit made from a stale belief introduces a silent bug — the kind that only surfaces during review or testing, long after the mistaken assumption was made. `/belief-audit` closes that gap at the cheapest possible moment: before the next edit, not after.

## When to use it

Reach for `/belief-audit` any time the continuity of Claude's file knowledge may have broken:

- After a session compacts — the audit fires automatically on every `PostCompact` event, but you can also run it manually to see the results.
- After a handoff from another agent, or after resuming work from a different session.
- After returning to a file that was last edited more than a few dozen turns ago.
- Any time you suspect a background process, hook, or external tool may have modified a tracked file outside of Claude's awareness.

Do not use it for runtime behavior verification — `/belief-audit` confirms that Claude's model of a file's contents matches disk, not that the code works correctly. Use [`/verify`](../evaluator/verify.md) for runtime correctness instead.

## Best practices

- **Re-read every drifted file before editing.** A drift report with exit code 1 is a hard stop: re-read the flagged files before proceeding with any further edits. Editing from a stale snapshot compounds the error rather than correcting it.
- **Run it right after compaction, not just before editing.** The automatic `PostCompact` hook runs the audit, but its results go to a log file. Invoking the skill manually surfaces the report directly in the conversation where you can act on it immediately.
- **Use a larger N after long absences.** The default of 5 files covers recent activity, but if you are returning to a project after days away, passing a larger count (e.g., `/belief-audit 15`) gives broader coverage of files that may have drifted in the interim.
- **Treat "no snapshots recorded yet" as expected on first run.** If `.claude/state/belief.jsonl` does not exist, the skill exits 0 with a notice — there is nothing to audit, which is not an error.
- **Ensure `sha256sum` is available.** The skill uses GNU coreutils `sha256sum`. If it is absent, the script exits silently and does not provide coverage. Install coreutils to get reliable auditing.

## How it improves your workflow

Without belief-audit, divergence between Claude's model of a file and the actual file on disk is invisible until something goes wrong — a duplicate change, a conflict, or a regression. With belief-audit, that divergence surfaces in under ten milliseconds, in the form of a table with the recorded hash and the current hash side by side. Every session that touches multiple files in sequence benefits from this: the cost of a re-read before an edit is seconds; the cost of debugging an edit made on stale assumptions can be hours. The automatic `PostCompact` trigger means you get protection without having to remember to run it — and the manual invocation gives you an on-demand check whenever the situation warrants one.

## Related

- [`/checkpoint`](checkpoint.md) — mid-session drift check focused on task scope and plan alignment, not file-content integrity
- [`/verify`](../evaluator/verify.md) — runtime behavior verification; use after belief-audit confirms you are editing the right version of a file
- [`../long-session/session-resume.md`](../long-session/session-resume.md) — session handoff and resumption; belief-audit should follow any resume from a different session
- [`../long-session/progress-log.md`](../long-session/progress-log.md) — records session state before compaction; pairs naturally with post-compact belief-audit
- [Belief-Audit Design Reference](../../belief-audit.md) — deeper explanation of the sha256 snapshot mechanism, cost analysis, and the `|Bk − Sk|` formalism from SyncMind
- [Architecture](../../architecture.md) — where belief-state management fits in the 8-component harness model
