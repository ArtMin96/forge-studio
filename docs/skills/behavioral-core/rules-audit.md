# Rules Audit

`/rules-audit` is a self-discipline pass over your current Claude Code session. It reads back through the transcript and flags where the assistant drifted from the behavioral rules — sycophancy, unnecessary apologies, scope creep, focus drift, filler, template formatting, restated questions, and hedged non-answers — then reports counts and an overall discipline score. It is read-only: it inspects and reports, it never edits your code.

It belongs to the `behavioral-core` plugin, which injects 16 behavioral rules into every turn via the `behavioral-anchor.sh` hook. Those rules steer behavior going forward; `/rules-audit` checks, after the fact, whether the steering actually held.

---

## Install

```bash
/plugin install behavioral-core@forge-studio
```

The audit ships with the plugin. Run it by typing:

```text
/rules-audit
```

No arguments. It scans the conversation you are already in.

## Why you need it

The rules are injected at the bottom of every prompt, but injection is not enforcement. Over a long session the model can slide back into the defaults it was trained on — opening with "Great question!", padding answers, refactoring code you never asked it to touch, or answering "A or B?" with a fence-sitting pros-and-cons list. These regressions are quiet. Individually each one is small; together they erode trust and waste tokens.

`/rules-audit` makes the drift visible. Instead of a vague sense that the session "got sloppy," you get a concrete tally: which rule, how many times, in which message, and what should have been said instead. That turns an unmeasurable feeling into something you can act on — keep going, correct course, or start a fresh session.

## What it checks

The audit scans for eight classes of violation, each mapped to a behavioral rule:

| Check | Catches | Backing rule |
|-------|---------|--------------|
| Sycophancy | "You're right", "Great question", "Absolutely", reflexive agreement | `10-tone` |
| Unnecessary Apologies | "Sorry", "I apologize" with no actual harm caused | `10-tone` |
| Scope Creep | unrequested features, refactors, comments, over-engineering | `60-minimal-changes` |
| Focus Violations | reading unrelated files, exploring without purpose | `80-no-redundant-exploration` |
| Filler Language | "Let me…", "I'll go ahead and…", trailing summaries | `25-brevity` |
| Formatting Defaults | bullets/headers/numbered lists where prose would do | `20-formatting` |
| Question Restatement & Padding | repeating your question back, padding past the point | `25-brevity` |
| Hedged Non-Answers | "A or B?" answered with symmetric pros/cons and no pick | `85-take-a-position` |

Output is a fixed block — counts per category, an overall `X/10` rating, then each violation listed with the offending message and the better alternative.

## When to use it

Reach for it when the session has run long enough for drift to accumulate or when output quality has noticeably dropped:

- **Near the end of a long session**, before you decide whether to continue or `/clear`.
- **After a stretch of low-discipline turns** — the assistant suddenly chatty, agreeable, or expansive.
- **When tuning your setup** — to confirm the `behavioral-anchor` hook is actually shaping output, or to measure the effect of adding, removing, or editing a rule in `rules.d/`.

Do not use it for real-time enforcement. The audit only inspects history; it cannot stop a bad action mid-flight. To hard-block destructive or out-of-scope actions as they happen, use `/safe-mode` and `/scope` instead.

## Best practices

- **Audit, then act.** A clean report is a green light to keep going. A noisy one is a signal to correct the specific behavior — or to start fresh, since drift tends to compound rather than self-correct within the same context.
- **Use it as a feedback loop on your rules.** If a category keeps showing violations, the rule may be too weak or the task may genuinely conflict with it. Edit the matching file in `plugins/behavioral-core/hooks/rules.d/` — the hook re-reads the directory every turn, so changes take effect immediately.
- **Pair it with brevity limits.** High Filler or Restate/Pad counts usually mean the session has lost its terseness; `/timebox` enforces a hard message ceiling that pushes responses back toward signal.
- **Run it before a handoff.** Auditing before `/progress-log` or a compaction gives you a quality read on the work being summarized, not just its content.

## How it improves your workflow

Behavioral steering is the cheap half of keeping an agent useful over a long session — about 150 tokens per turn. The expensive failure is silent drift: a model that quietly reverts to verbose, agreeable, scope-creeping defaults while you stop noticing. `/rules-audit` closes that gap. It converts the 16 always-on rules from hopeful instructions into something you can verify, giving you a measurable discipline signal you can check at any point and a fast way to decide whether the current context is still worth continuing in. Combined with the live guards (`scope-guard`, `block-destructive`) and the forward-looking rules, it completes the loop: steer ahead of time, block in the moment, audit after the fact.

## Related

- [Architecture](../../architecture.md) — where behavioral steering sits in the 8-component harness model
- [`/scope`](scope.md) · [`/timebox`](timebox.md) · [`/safe-mode`](safe-mode.md) — the live guards in `behavioral-core` that enforce in the moment, whereas `/rules-audit` inspects after the fact
