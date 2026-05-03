# Forge Studio — Next-Session Handoff

Self-contained prompts for the next Claude Code session. Each section is paste-ready. Pick one, paste it as your first message, and Claude has full context to execute without re-asking.

Audit context for what came before this handoff: `~/.claude/plans/i-want-you-to-idempotent-lampson.md` (the verified-truth plan from the prior session).

---

## Prompt 1 — Exercise the SEPL Self-Evolution Loop end-to-end

**Status**: 🔵 NEVER FIRED. The protocol is implemented and documented but no `propose → assess → commit → rollback` cycle has run on real data. `.claude/lineage/ledger.jsonl` does not exist on this machine. Until exercised, the loop's real-world reliability is unproven.

**Why this matters**: Self-evolution is the marketplace's most ambitious component (Component 8 of the harness model). Documentation says it works; we have not seen it work. Run it on a low-stakes proposal so the next time we trust it for a real harness change, we know the failure modes.

**Paste this prompt to start**:

```
Exercise the SEPL self-evolution loop on a low-stakes proposal so we know the failure modes before relying on it.

Context: forge-studio repo at /home/arthur/Projects/forge-studio. The protocol is documented in docs/self-evolution.md and HARNESS_SPEC.md §Self-Evolution Protocol. Skills involved: /evolve, /trace-evolve, /assess-proposal, /commit-proposal, /rollback, /lineage-audit.

Pick a small, reversible target — e.g.:
  - Tweak a single behavioral rule in plugins/behavioral-core/hooks/rules.d/
  - Adjust a single env var in .claude/settings.json (e.g. WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD from 0.75 to 0.80)
  - Add one line to a memory topic

Do NOT pick: a hook script, an agent definition, anything in plugins/workflow/, anything irreversible.

Required steps and verification:
1. Run /trace-evolve to surface a real failure cluster (or skip if none exist; manually draft a proposal artifact instead).
2. Run /evolve to drive propose → assess → commit. CONFIRM at each user-prompt before committing.
3. After commit: verify .claude/lineage/ledger.jsonl exists and contains 3 entries (propose, assess, commit) for the same resource and version. Quote the JSONL lines.
4. Verify the snapshot file at .claude/lineage/versions/<slug>/<prev-version> exists and contains the previous content. Quote the diff (snapshot vs current).
5. Run /lineage-audit. Verify all invariants pass (operator sequence, snapshot presence, append-only, registry slugs).
6. Run /rollback <slug>. Verify the resource reverts to prior content AND a 4th entry appears in the ledger (rollback). Verify a forward-snapshot was written so re-rollforward is possible.
7. Re-run /lineage-audit. Confirm 4 entries now, all invariants still pass.

Failure modes to actively probe:
- What happens if you Ctrl+C between propose and assess? Does ledger contain an orphan propose entry? Document it.
- What happens if /commit-proposal runs without a preceding pass-assess? Confirm it refuses (HARNESS_SPEC line ~411 says it must).
- What happens if you delete the snapshot file then run /rollback? Confirm it refuses cleanly (no half-rollback).

Deliverable: a markdown report at docs/research/sepl-shakedown-report.md with:
  - Target chosen + reasoning
  - The 4 ledger entries (verbatim JSONL)
  - The 2 snapshot files (paths + brief diff summary)
  - /lineage-audit output (verbatim)
  - Failure-mode probe results (what happened, what should happen, gap if any)
  - Pass/Fail verdict per protocol invariant in HARNESS_SPEC.md §Ledger Invariants

Constraints:
- Do not commit any real harness changes after the exercise — /rollback at the end so the marketplace returns to current state.
- Do not skip /assess-proposal under any circumstance — that defeats the test.
- Verify with proof, not claims (paste actual ledger lines, not summaries).
```

**Time estimate**: 30-45 min if smooth, 60-90 min if probing failures uncovers real bugs.

**Files Claude will need**:
- `/home/arthur/Projects/forge-studio/docs/self-evolution.md`
- `/home/arthur/Projects/forge-studio/HARNESS_SPEC.md` §Self-Evolution Protocol (lines 388-440)
- `/home/arthur/Projects/forge-studio/plugins/workflow/skills/evolve/SKILL.md`
- `/home/arthur/Projects/forge-studio/plugins/evaluator/skills/assess-proposal/SKILL.md`
- `/home/arthur/Projects/forge-studio/plugins/workflow/skills/commit-proposal/SKILL.md`
- `/home/arthur/Projects/forge-studio/plugins/workflow/skills/rollback/SKILL.md`
- `/home/arthur/Projects/forge-studio/plugins/memory/skills/lineage-audit/SKILL.md`

---

## Prompt 2 — Add auto-memory recall on SessionStart

**Status**: 🔵 GAP. Memory exists (`/recall`, `/remember`, three-tier architecture) but is invoked manually. After a `/clear` or new session, relevant memory topics do not surface — Claude has to be told "go look at memory." For a 10+ tasks/day workflow this is friction.

**Why this matters**: The whole point of memory is unprompted recall. If the user has to remember to `/recall <topic>` every session, we've built a worse version of CLAUDE.md.

**Paste this prompt to start**:

```
Add auto-memory recall on SessionStart for forge-studio. The memory plugin already has /recall and /remember but no SessionStart hook. Goal: surface relevant memory topics automatically when a fresh session begins, the same way long-session/surface-progress.sh surfaces claude-progress.txt.

Context: forge-studio repo at /home/arthur/Projects/forge-studio. Memory plugin lives at plugins/memory/. Topic files live at .claude/memory/topics/<slug>.md (per-project) and ~/.claude/projects/<project-slug>/memory/MEMORY.md (per-project user-scope).

Design constraints (read before coding):
1. Silent on no-recent-topics — must not spam every session start.
2. Surface ranking: most-recently-modified first, then by topic-relevance heuristics (filename match against current branch / recent commits).
3. Hard cap: surface at most 3 topics, at most ~500 chars each. The point is a hint, not a dump.
4. Opt-out via env var FORGE_MEMORY_AUTO_RECALL=0 (forge convention).
5. Real-repo gate identical to surface-progress.sh and bootstrap-substrate.sh (.git || package.json || composer.json || pyproject.toml || Cargo.toml || go.mod). Bail otherwise.
6. Idempotency not required (read-only hook), but performance matters — keep < 50ms.
7. Handle BOTH user-scope memory (~/.claude/projects/<slug>/memory/) AND project-local memory (.claude/memory/topics/) — prefer project-local when both exist.

Implementation plan (propose first, get my confirmation before writing code):
1. New hook plugins/memory/hooks/auto-recall.sh
2. New plugins/memory/hooks/hooks.json (currently the memory plugin has no hooks.json — confirm via `ls plugins/memory/hooks/` first)
3. Hook reads memory index, ranks topics, prints formatted summary like:
   [memory] 3 recent topics surfaced (run /recall <slug> to load full content):
     • <slug-1> — <one-line description from frontmatter>
     • <slug-2> — <one-line description>
     • <slug-3> — <one-line description>
4. Update README.md count line: 56 → 57 hooks
5. Update README.md hook summary: SessionStart 9 → 10
6. Update docs/architecture.md Forge Hook Deployment table — add row in Session Lifecycle section
7. chmod +x the script

Verification (must produce evidence, not claims):
- bash -n script.sh && echo "syntax OK"
- Run via fresh /tmp test fixture with 5 fake topics — confirm only top 3 surface, sorted by mtime
- Run with no topics directory — confirm silent (no output)
- Run with FORGE_MEMORY_AUTO_RECALL=0 — confirm silent
- Run validate-marketplace + entropy-scan: counts match, no failures
- Show diff of README.md, architecture.md edits

Failure modes to think through before coding:
- Topic frontmatter missing or malformed — must not crash hook (silent degrade)
- 100+ topics in directory — must still complete < 50ms (no per-topic file read)
- Symlinks in topics/ — handle without infinite loop

Constraint: change one thing at a time. Write the hook first, verify in isolation. Then register in hooks.json. Then update docs. Each step verified separately before moving on.
```

**Time estimate**: 60-90 min including verification + doc updates.

**Files Claude will need**:
- `/home/arthur/Projects/forge-studio/plugins/memory/skills/recall/SKILL.md`
- `/home/arthur/Projects/forge-studio/plugins/memory/skills/remember/SKILL.md`
- `/home/arthur/Projects/forge-studio/plugins/long-session/hooks/surface-progress.sh` — copy real-repo gate and silent-on-empty pattern
- `/home/arthur/Projects/forge-studio/plugins/long-session/hooks/bootstrap-substrate.sh` — copy real-repo gate + opt-out env var pattern
- `/home/arthur/.claude/projects/-home-arthur-Projects-forge-studio/memory/MEMORY.md` — example index format

---

## Prompt 3 — Wire trace-evolve → /evolve auto-chain (small UX win)

**Status**: 🔵 GAP from the verified plan (§3). Both skills exist; user must manually chain them.

**Paste this prompt to start**:

```
In forge-studio, /trace-evolve (traces plugin) emits a cluster report and writes proposal drafts to .claude/lineage/proposals/. /evolve (workflow plugin) is the orchestrator that drives propose → assess → commit. They don't auto-chain — the user has to read the trace-evolve output, find the proposal artifact paths, then invoke /evolve manually.

Goal: when /trace-evolve produces ≥1 proposal, emit a single ledger 'signal' entry that /evolve picks up automatically as input. /evolve should detect the signal on its next invocation and offer to drive each proposal through assess + commit, with user confirmation.

Read the SKILL.md files for both skills before designing:
- /home/arthur/Projects/forge-studio/plugins/traces/skills/trace-evolve/SKILL.md
- /home/arthur/Projects/forge-studio/plugins/workflow/skills/evolve/SKILL.md

Design constraints:
1. Do not auto-commit — user approval still required at the commit operator.
2. Signal entry uses a new ledger operator name 'signal' or extends the existing 'propose' format. Pick one and document why.
3. /evolve must be backward-compatible: if no signal, it falls back to current behavior.

Propose the design in a plan-mode plan first, get my confirmation, then implement.

Verify by:
- Running /trace-evolve on real trace data in ~/.claude/traces/. Confirm signal entry appears in ledger.
- Running /evolve. Confirm it detects the signal and walks through the proposals.
- Running /lineage-audit. Confirm new operator (if added) is recognized in invariants.
```

**Time estimate**: 90-120 min (design + impl + verify).

---

## Prompt 4 — `/router-tune` auto-drafts proposals

**Status**: 🔵 GAP from §3. Mechanically similar to Prompt 3.

**Paste this prompt to start**:

```
/router-tune (workflow plugin) analyzes /tmp/claude-router-*/classifications.jsonl for router miss-fires and emits a textual report. It does NOT auto-draft a proposal artifact for /evolve to pick up. User has to manually write the proposal markdown.

Goal: /router-tune auto-drafts proposal artifacts to .claude/lineage/proposals/<YYMMDD>-router-<slug>-v<N>.md when it identifies a confident threshold or regex tweak. Then /evolve picks it up automatically (assuming Prompt 3 is also implemented; if not, /router-tune emits the path so the user can hand it to /evolve manually).

Read /home/arthur/Projects/forge-studio/plugins/workflow/skills/router-tune/SKILL.md and /home/arthur/Projects/forge-studio/plugins/workflow/hooks/route-prompt.sh first.

Constraint: only auto-draft when confidence in the recommendation is high. False proposals are worse than no proposals because they consume /assess-proposal cycles. Pick a confidence threshold and document it.

Verify by:
- Running /router-tune on real classifications data. Confirm proposal artifact written.
- Quote the proposal markdown.
- Confirm filename slug matches the resource registry format from HARNESS_SPEC.md.
```

**Time estimate**: 60-90 min.

---

## Prompt 5 — `/assess-proposal` failures feed back to memory as constraints

**Status**: 🔵 GAP from §3. When `/assess-proposal` rejects a proposal repeatedly for the same reason (e.g., "single-variable-change violation"), nothing learns. The pattern recurs.

**Paste this prompt to start**:

```
In forge-studio, /assess-proposal (evaluator plugin) issues pass/fail/conditional verdicts on proposals. Failed proposals never feed back into memory. So if the same kind of mistake happens twice (e.g., "this proposes two unrelated changes in one artifact" — a single-variable-change violation), nothing learns and the next propose run can repeat the same mistake.

Goal: when /assess-proposal issues a 'fail' verdict AND a similar verdict has fired before, prompt the user (not auto-write) to /remember the failure pattern as a constraint. The constraint becomes a memory topic that future /evolve invocations surface to the proposer.

Read /home/arthur/Projects/forge-studio/plugins/evaluator/skills/assess-proposal/SKILL.md and /home/arthur/Projects/forge-studio/plugins/memory/skills/remember/SKILL.md.

Design constraints:
1. Do not auto-write memory — user must approve. (Memory bloat is a real risk.)
2. Only prompt when same failure category recurs ≥2 times within a 14-day window. Single failures are noise.
3. The memory topic must include the failure pattern + a counter-example (what would have passed).

Failure-category similarity: define what "same category" means before coding. Probably: same verdict.criteria failure (e.g., 'single_variable: false' fired twice). Document the heuristic.

Verify by simulating two failed proposals with the same criterion. Confirm the prompt fires, accept it, confirm memory topic created with both attempts referenced.
```

**Time estimate**: 90-120 min.

---

## Prompt 6 — Spec/features.json reconciliation

**Status**: 🔵 GAP from §3. `after-subagent.sh` updates `features.json` by matching `F<n>` IDs in commit messages. If commits don't cite IDs, features stay pending forever even after the work lands.

**Paste this prompt to start**:

```
In forge-studio, plugins/workflow/hooks/after-subagent.sh updates .claude/features.json by parsing commit subjects for F<n> IDs. If commits don't cite IDs (which is common — devs forget), features stay 'pending' even after the code lands. /verify writes results to .claude/gate/features.json with actual test outcomes.

Goal: a reconciliation step that flips features.json items to 'done' when:
- The corresponding entry in .claude/gate/features.json shows passed=true, AND
- Either the gate entry's verify_cmd matches the feature's verify_cmd, OR
- The gate entry's id matches.

Read plugins/workflow/hooks/after-subagent.sh:49-64 and plugins/evaluator/skills/verify/SKILL.md.

Two design options — pick one and justify:
A) New hook that fires after /verify completes (PostToolUse-ish but for skills — Claude Code may not support this; check first).
B) Extend after-subagent.sh to read .claude/gate/features.json on every fire, not just match against commit messages.

Constraint: do not regress the existing F<n>-from-commit-message path. Both must work.

Verify with a synthetic test fixture: features.json with 1 pending feature, gate/features.json with 1 passed entry matching by id, no commits at all. Run after-subagent.sh. Confirm flip.
```

**Time estimate**: 60-90 min.

---

## How to use this file

1. Pick ONE prompt (don't paste multiple in one session — context bloat).
2. Open a fresh Claude Code session in `/home/arthur/Projects/forge-studio`.
3. Paste the prompt verbatim as your first message.
4. Claude has full context (including SessionStart auto-bootstrap from this session's work) and can execute without re-asking.
5. Each prompt enforces: design first, verify with proof, change one thing at a time.

If you finish a prompt successfully, delete that section from this file (or move it to a `done-` archive) so the next session picks the next priority.

## Priority ranking (my read)

1. **Prompt 1 (SEPL exercise)** — highest. Until SEPL has fired once, the marketplace's most-cited feature is theoretical. Cheap to do.
2. **Prompt 2 (auto-memory recall)** — highest UX impact for daily workflow. The user explicitly mentioned the friction.
3. **Prompt 6 (spec/features reconciliation)** — small, mechanical, low risk. Closes a real silent-failure mode.
4. **Prompt 3 + 4 (auto-chain trace→evolve, router-tune→evolve)** — quality-of-life improvements. Both depend on Prompt 1 having validated the loop.
5. **Prompt 5 (assess-proposal → memory)** — most speculative. Memory bloat is a real risk; only do this after Prompts 1-4 prove the loop is reliable.
