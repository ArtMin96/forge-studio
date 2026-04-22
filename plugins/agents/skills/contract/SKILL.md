---
name: contract
description: Read and confirm the sprint contract from the active plan before implementation begins. Prevents context decay by forcing a fresh Read of criteria.
when_to_use: Before any non-trivial implementation step, especially when working inside a planner→generator→reviewer pipeline or when plan criteria may have decayed from long context.
allowed-tools:
  - Read
  - Glob
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
