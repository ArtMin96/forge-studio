# Devil's Advocate

`/devils-advocate` constructs the strongest possible argument against a design decision or approach you are considering. Given the decision as an argument, it systematically analyzes what could go wrong, what tradeoff is being made and whether the person making it is fully aware, proposes at least one concrete alternative with a specific rationale, and delivers a final verdict: proceed, reconsider, or strong objection. It is intentionally one-sided — its job is to find holes, not to be fair.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/devils-advocate use a single global event bus for all plugin communication
```

The argument is the decision or approach to challenge.

## Why you need it

The most dangerous design decisions are the ones where everyone in the room agrees. When consensus forms quickly, the group stops looking for failure modes. Smart people share blind spots, and the fact that an approach feels obviously correct is often a sign that its flaws are non-obvious — which makes them the most expensive to discover later. Architecture choices made without adversarial pressure tend to survive until the first production incident.

`/devils-advocate` fills the role of the skeptic who hasn't been worn down by the enthusiasm of the room. Because it is explicitly not trying to be balanced, it surfaces concrete risks and sacrificed constraints that a more measured analysis would bury in caveats. Sometimes the original decision is still the right one after the analysis — but you should know why, not just feel it.

## When to use it

- Before locking in an architectural approach — especially when the first option considered feels obviously correct.
- Before committing to a major refactor direction when alternatives exist.
- During plan authoring when a design has a single winning path and no one has argued against it.
- When a technical decision has downstream maintenance consequences that are easy to discount in the moment.

Do not use it for reviewing code that already exists — use `/challenge` for self-review, `/verify` for diff verification, or `/assess-proposal` for the SEPL gate instead; this skill argues forward-looking design decisions.

## Best practices

- **Supply a specific decision, not a vague topic.** "Use Redis for session storage" produces a more useful challenge than "how to handle sessions." The more concrete the decision, the more concrete the objection.
- **Read the alternative seriously.** The skill is required to propose at least one concrete alternative. If the alternative is actually better in your context, the verdict will say so plainly — treat that as signal, not as an artifact of the prompt.
- **Run it before the plan is written, not after.** A devil's advocate argument against an approach you have already spec'd out and committed to costs more to act on. The right moment is when the decision is still provisional.
- **Distinguish "proceed" from "no risk."** A "Proceed" verdict means the risks are acceptable, not that the risks don't exist. Keep the objections in mind during implementation.

## How it improves your workflow

Architecture decisions are cheap to change before they are made and expensive to change after they are implemented. `/devils-advocate` moves the cost of finding a design's worst failure modes from implementation-time to decision-time — when changing course costs a conversation rather than a rewrite. Even when the verdict confirms the original direction, the explicit articulation of the strongest objection and the concrete alternative gives you a clearer mental model of what you are trading away, which makes the downstream implementation more deliberate.

## Related

- [`challenge.md`](challenge.md) — adversarial review of code already written; `/devils-advocate` argues decisions before code exists
- [`verify.md`](verify.md) — evidence gate for completed work; not a design critique
- [`grill-me.md`](grill-me.md) — structured clarification interview; use it for resolving open questions rather than arguing against a direction
- [`assess-proposal.md`](assess-proposal.md) — SEPL gate for harness evolution proposals
- [Architecture](../../architecture.md) — where evaluation fits in the 8-component harness model
