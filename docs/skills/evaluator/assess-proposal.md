# Assess Proposal

`/assess-proposal` is the second operator in the SEPL (self-evolution protocol loop): propose → **assess** → commit. Given the path to a proposal artifact under `.claude/lineage/proposals/`, it runs a structured pass/fail review across a mandatory contract check and four criteria — single-variable change, root-cause alignment, honest token/behavior impact, and no regression of existing rules — then writes a verdict JSON and appends a ledger entry. It runs in a forked `reviewer` subagent so the assessor cannot silently fix what it is evaluating, forcing an honest call.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/assess-proposal .claude/lineage/proposals/0420-brevity-v3.md
```

The argument is the path to a proposal artifact. If omitted, the skill reads the most recent file in `.claude/lineage/proposals/`.

## Why you need it

Harness self-evolution is powerful and dangerous in equal measure. Without a structured gate, a proposal can slip through that changes two things at once (hiding blast radius), patches a symptom rather than the root cause, understates its token cost, or quietly contradicts a rule you already rely on. None of these failures are obvious from the proposal text alone — they require reading neighboring resources and checking impact estimates against documented norms.

`/assess-proposal` makes every one of those checks mechanical. It also requires a `change_contract:` block before it will score anything: a proposal without a falsifiable test command gets refused outright, because there is no agreed way to confirm the change works or undo it safely. The result is a verdict you can trust rather than a rubber stamp you performed.

## When to use it

- Immediately after `/evolve` writes a proposal artifact, before any user approval or `/commit-proposal`.
- Any time a proposal was produced by `/auto-tune-skill` — the skill also runs the regression-gate script (`regression-gate.sh`) in that case.
- When you want an independent second opinion on a proposal you drafted manually.

Do not use it for general code review of un-versioned changes — use `/challenge` or `/devils-advocate` instead; this skill is the SEPL `assess` operator gate against versioned harness resources.

## Best practices

- **Supply the path explicitly.** The "most recent proposal" fallback is convenient but fragile if two proposals landed in quick succession. Name the file.
- **Fix the contract block before re-submitting.** The skill stops at a missing or incomplete `change_contract:` section and names the missing field verbatim. Correct exactly that field and re-run — do not guess at what else might be wrong.
- **Read the blockers, not just the verdict.** A `conditional` verdict means there is a specific cleanup path. The `blockers` array tells you what to fix; the rationale explains why.
- **Treat regression-gate exit 3 as a hard stop.** If `regression-gate.sh` exits 3 (environment error or restore failure), inspect for leftover `*.regression-bak.*` files before retrying — the skill cannot guarantee the SKILL.md was restored byte-identical.
- **Do not modify the proposal yourself to make it pass.** The assessor is read-only by design; patching the proposal to sneak through the gate defeats the point. Revise the proposal outside the skill, then re-run.

## How it improves your workflow

Every SEPL commit is a permanent change to the harness you run every session. `/assess-proposal` is the gate that makes those commits trustworthy rather than hopeful. By enforcing a falsifiable test command, rejecting multi-variable bundles, and requiring honest impact estimates, it ensures that each change is legible, reversible, and non-regressive before it lands — converting the proposal review from a manual judgment call into a reproducible pass/fail record with evidence.

## Related

- [`verify.md`](verify.md) — the in-line evidence gate for ordinary task completion; assess-proposal is its SEPL-specific counterpart
- [`score-rubric.md`](score-rubric.md) — generic weighted criterion scoring outside the SEPL context
- [`postmortem.md`](postmortem.md) — run after a failed proposal lands and causes a regression
- [`prediction-audit.md`](prediction-audit.md) — audits impact predictions from already-committed proposals over time
- [Architecture](../../architecture.md) — how self-evolution fits the 8-component harness model
