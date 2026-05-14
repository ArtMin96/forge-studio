---
name: contract
description: Use whenever a generator agent or implementation step is about to begin work from a plan file — re-read the sprint contract verbatim and confirm the success criteria before writing any code. Prevents context decay by forcing a fresh Read of the criteria from disk rather than trusting earlier-in-session memory.
when_to_use: Invoke at the start of every non-trivial implementation turn, when a planner→generator→reviewer pipeline hands off to the generator, when plan criteria may have decayed after long context, or whenever a step claims "done" without an evidence link. Do NOT use for one-line edits or trivial fixes — direct work is fine; reach for `/scope` instead when the task itself needs definition.
paths:
  - ".claude/plans/**/*.md"
allowed-tools:
  - Read
  - Glob
counterexamples:
  - "One-line edits or trivial typo fixes — direct work is fine; no plan contract to read."
  - "When no plan file exists in .claude/plans/ — nothing to re-read."
  - "When the task itself needs definition — use /scope instead."
contract:
  required_outputs:
    - "Contract criteria printed verbatim with UNDERSTOOD or UNCLEAR per item."
  budget: "1 model turn"
  permission_scope: "Read-only on .claude/plans/"
  completion_conditions:
    - "All criteria acknowledged (each marked UNDERSTOOD or UNCLEAR with explanation)."
    - "Any UNCLEAR item causes STOP — no Edit/Write proceeds."
  output_paths:
    - "stdout"
logical: sprint contract criteria re-printed verbatim and acknowledged before any Edit/Write
---

# Contract Confirmation

Mechanically re-read the sprint contract from the active plan. This prevents relying on decaying context — the criteria are loaded fresh every time.

## Instructions

1. **Find the active plan:**
   ```
   Glob: .claude/plans/*.md
   ```
   Read the most recently modified plan file.

2. **Extract the Contract section:**
   Look for `## Contract` in the plan. If not found:
   ```
   NO CONTRACT FOUND in {plan file}.
   This plan was not created with the Pipeline (P/G/R) pattern.
   Proceeding without contract — use the plan's file list and description as guidance.
   ```

3. **Present criteria for confirmation:**
   For each criterion in the contract, output:
   ```
   CONTRACT CRITERIA:
   1. {criterion} — [UNDERSTOOD / UNCLEAR: {what's ambiguous}]
   2. {criterion} — [UNDERSTOOD / UNCLEAR: {what's ambiguous}]
   ...
   VERIFICATION: {verification method from contract}
   ```

4. **Decision:**
   - All criteria UNDERSTOOD → proceed with implementation
   - Any criteria UNCLEAR → STOP. Report what's ambiguous. Do not guess.
   - Criterion is infeasible given current codebase → STOP. Report why.

## Why This Exists

In long sessions, the generator's memory of plan criteria decays. This skill forces an actual `Read` tool call on the plan file, ensuring criteria are loaded fresh into context rather than recalled from earlier (potentially compacted) turns. Research (Anthropic, 2026): file-based handoffs outperform in-context memory for multi-agent coordination.

## Rebuttals

Common rationalizations for skipping the contract re-read, with rebuttals:

| Excuse | Rebuttal |
|---|---|
| "I remember the criteria from the plan." | Memory across compaction is unreliable — the principle this skill exists to enforce. Re-read costs ≤ 200 tokens; a missed criterion costs the whole sprint. |
| "The task is small enough not to need this." | "Small" is the most common pre-condition for scope creep. Re-read confirms the bound; skipping it removes the bound. |
| "The plan was clear when I read it earlier." | Plans are amended. The disk version is canonical; conversation memory is not. |
| "I'm already mid-edit." | Stop the edit. The Contract may forbid the file you're touching. The 30-second cost of pausing is lower than reverting a wrong edit. |
