---
name: forward-briefing
description: Produce `.claude/forward-briefing.md` — a forward-framed view of the last 5 progress entries. Re-presents accumulated blockers as open questions and surfaces next steps first, so the resuming session starts in a problem-solving posture rather than a failure-replay posture.
when_to_use: Reach for this at the start of a session when `claude-progress.txt` has accumulated several entries with `Blockers:` sections — a few sessions of struggle tend to front-load negative framing in the SessionStart briefing. Running `/forward-briefing` produces a derived artifact (`.claude/forward-briefing.md`) that `surface-progress.sh` will prefer at the next `SessionStart`. Do NOT use for writing the progress log itself — that's `/progress-log`; do NOT use for a full session briefing including spec, features, and git state — that's `/session-resume`.
paths:
  - "claude-progress.txt"
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Bash
scheduling: after `/progress-log` has appended a session with non-trivial blockers, or whenever the SessionStart briefing feels heavy with accumulated failure context
structural:
  - Read last 5 entries from claude-progress.txt (blank-line-separated blocks)
  - Compose three forward-framed sections in .claude/forward-briefing.md
  - Stamp file with generation timestamp so surface-progress.sh can compare freshness
logical: .claude/forward-briefing.md written with Last-session-left-at, Direct-next-steps, and Open-questions sections; timestamp header present
---

# /forward-briefing — Forward-Framed Session Briefing

## Why This Skill Exists

Liu et al. (arXiv:2605.08060v1) studied how accumulated history affects LLM reasoning. §4.5 + Appendix H Table 13 reports a sanitization sweep: at fixed prompt length (HL=80), replacing negative accumulated content with cooperative history lifted Llama-3.3-70B Trust-Game cooperation from 6.9% to 97.43%. Content, not length, drives the curse.

The domain of that paper is multi-agent social dilemmas, not software development. The transferable mechanism is narrower: at a fixed context window, the *framing* of injected history shapes forward-looking reasoning. A log that reads "Blockers: — still failing — can't proceed — blocked again" biases the opening posture of a session toward diagnosis and defense. The same facts rewritten as "Open question: what would unblock X?" bias toward action.

This skill applies that content-shift idea to dev-session resume briefings. It does not touch `claude-progress.txt`; it produces a regeneratable derived view.

## Append-Only Invariant

This skill does NOT edit `claude-progress.txt`. The log is append-only by design (see `/progress-log`). `.claude/forward-briefing.md` is a derived, regeneratable artifact. If the briefing is deleted, re-running `/forward-briefing` regenerates it. If `claude-progress.txt` is updated after the briefing was last generated, `surface-progress.sh` detects the staleness via mtime comparison and falls back to the verbatim tail automatically.

## Process

1. **Ensure `.claude/` exists.**
   ```bash
   mkdir -p .claude
   ```

2. **Read last 5 entries from `claude-progress.txt`.**
   Entries are blank-line-separated blocks. If the file is missing, write a stub briefing and exit:
   ```
   No prior session log. Start with /feature-list or /living-spec.
   ```

3. **Parse each entry for three field types:**
   - `Done:` and `In progress:` lines → summarize current state
   - `Next:` lines → collect for direct-next-steps
   - `Blockers:` lines → collect for reframing as open questions

4. **Compose `.claude/forward-briefing.md`** with this structure:

   ```markdown
   <!-- generated: <UTC ISO8601> from claude-progress.txt -->

   ## Last session left at

   <one-line summary drawn from the most recent entry's Done: and In progress: fields>

   ## Direct next steps

   - <Next: item from oldest of the 5 entries>
   - <Next: item — deduplicated, preserving original wording, oldest first>

   ## Open questions

   - <Blockers: item reframed as a question or probe — see examples below>
   ```

5. **Reframing Blockers as open questions — examples:**
   - `Blockers: - Need confirmation on whether X counts as Y` → `Does X count as Y? (ask user, then commit the version bump)`
   - `Blockers: - Auth token missing in CI` → `What provides the auth token in CI — env var, secrets store, or manual step?`
   - `Blockers: - Test flaky, cause unknown` → `What is the smallest reliable reproduction of the flaky test?`
   - Preserve the factual content; rewrite only the framing from "stuck on X" to "what resolves X?"

6. **Write the file.** Overwrite any existing `.claude/forward-briefing.md`.

## Execution Checklist

- [ ] `mkdir -p .claude` (idempotent)
- [ ] Read `claude-progress.txt` — if absent, write stub, done
- [ ] Parse last 5 entries (blank-line blocks)
- [ ] Collect Done/In-progress from most recent entry → Last-session-left-at
- [ ] Collect Next: items across 5 entries → deduplicate → oldest first
- [ ] Collect Blockers: items across 5 entries → reframe as questions
- [ ] Write `.claude/forward-briefing.md` with timestamp header
- [ ] Confirm file written; report path and section counts

## Input / Output Example

**Input** — last 2 entries of `claude-progress.txt`:

```
2026-05-10 session: version-bump
Done: bumped plugin.json to 1.1.0
In progress: marketplace.json update
Blockers: - Need confirmation on whether the long-session entry counts as a patch or minor bump
Next: - confirm version bump policy with user
Next: - update marketplace.json

2026-05-11 session: marketplace-sync
Done: marketplace.json updated
In progress: README counts
Blockers:
Next: - verify count.sh output matches README header
```

**Output** — `.claude/forward-briefing.md`:

```markdown
<!-- generated: 2026-05-11T14:32:00Z from claude-progress.txt -->

## Last session left at

README counts in progress; marketplace.json updated.

## Direct next steps

- confirm version bump policy with user
- update marketplace.json
- verify count.sh output matches README header

## Open questions

- Does the long-session entry count as a patch or minor bump? (ask user, then commit the version bump)
```

## Failure Modes

- **`claude-progress.txt` missing** — write stub briefing: `No prior session log. Start with /feature-list or /living-spec.` Exit without error; this is a soft enhancement.
- **`.claude/` directory missing** — `mkdir -p .claude/` first; this is idempotent and safe in any repo.
- **All 5 entries have empty Blockers:** — the Open questions section is omitted or shows "No open blockers from recent sessions."
- **Duplicate Next: items across entries** — deduplicate by exact string match; preserve the oldest occurrence.
