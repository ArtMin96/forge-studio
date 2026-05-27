# Grill Me

`/grill-me` runs a structured design interview, walking every branch of a plan's decision tree and asking one question at a time until shared understanding is reached. For each question it provides its own recommended answer, so the interview is not just interrogation — it is a collaborative clarification pass. If the active plan has unresolved open questions tagged as goal or context dimensions, invoking the skill at the start of plan execution surfaces those ambiguities before the generator touches any files.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/grill-me
```

No arguments needed when interrogating the current plan. The skill reads the plan and walks its branches automatically.

## Why you need it

Under-specified plans are the most common source of mid-implementation surprises. A plan that looks complete at the top level often has silent forks: an assumption about whether a new endpoint is authenticated, an unstated preference between two data models, a missing decision about backward compatibility. When those forks are discovered during implementation rather than during planning, the cost is a revert, a rewrite, or a conversation that interrupts the work.

`/grill-me` surfaces those forks before any code is written. Because it asks one question at a time and provides a recommended answer for each, it moves fast — you confirm, correct, or override the recommendation rather than composing answers from scratch. The result is a plan with all branches resolved and the reasoning on record before the generator starts.

## When to use it

- Before handing a non-trivial plan to `/dispatch`, when requirements feel under-specified or have more than one interpretation.
- At the start of plan execution when the active plan has unresolved `(dimension: goal` or `(dimension: context` open questions — these are the most expensive ambiguities to discover late.
- When a design has multiple plausible approaches and no one has committed to a direction yet.
- When the user says "grill me," "interview me," or "stress-test this plan."

Do not use it for arguing against a chosen direction — use `/devils-advocate` instead; grill-me is about clarification, not opposition.

## Best practices

- **Answer one question at a time.** The skill explicitly asks questions sequentially — do not answer several at once, because later answers often depend on earlier ones.
- **Let it explore the codebase before you answer.** If a question can be resolved by reading existing code, the skill will do that automatically. Wait for that result before adding your own answer; the code is more reliable than your memory of it.
- **Override recommended answers freely.** The skill's recommendations are its best guess based on context. Correction is always better than silent acceptance of a wrong assumption.
- **Run it on the plan, not on a feeling.** The most productive sessions start with the plan file in context so the skill can trace actual decision branches, not hypothetical ones.

## How it improves your workflow

Plan ambiguity is cheap to resolve in a conversation and expensive to discover mid-implementation. `/grill-me` converts a plan with silent forks into one where every decision branch is explicit, every assumption is stated, and the reasoning behind each choice is on record. That record becomes the answer to "why did we do it this way?" six weeks later — and the absence of mid-implementation surprises is the payoff that justifies the upfront interview time.

## Related

- [`devils-advocate.md`](devils-advocate.md) — argues against a direction already chosen; grill-me resolves ambiguity before a direction is locked
- [`verify.md`](verify.md) — the evidence gate at the end of execution; grill-me runs at the beginning
- [`../agents/contract.md`](../agents/contract.md) — re-reads the plan's success criteria; use after grill-me resolves the open questions
- [`../workflow/orchestrate.md`](../workflow/orchestrate.md) — the pipeline that dispatches generators; grill-me runs before orchestrate to resolve open plan questions
- [Architecture](../../architecture.md) — where planning and evaluation fit in the 8-component harness model
