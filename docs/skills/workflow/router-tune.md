# Router Tune

`/router-tune` analyzes the classification history written by `route-prompt.sh`, clusters miss-fires into at most three improvement categories, and emits concrete proposal artifacts — threshold tweaks or regex changes — that [`/evolve`](evolve.md) can then drive through the assess-commit pipeline. It belongs to the `workflow` plugin. The skill itself makes no changes; it produces proposals only.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/router-tune
```

No arguments. The skill reads classification logs from `/tmp/claude-router-*/classifications.jsonl` automatically.

## Why you need it

The `route-prompt.sh` hook classifies every prompt and recommends a dispatch pattern. When that classification is consistently wrong — the router says `single-agent` but you keep overriding to `pipeline`, or it emits `route=none` on prompts where you then dispatch work — the threshold or regex rules that drive the classification are miscalibrated. Eyeballing the logs and adjusting the threshold manually is fragile: you are making a change without evidence, without a baseline, and without a way to measure whether the change helped.

`/router-tune` replaces that manual process with a data-driven one. It aggregates classification history across sessions, detects the two miss-fire patterns that indicate real miscalibration (low-confidence routes that you override, and `route=none` routes that precede actual dispatch), clusters them by kind, and writes a structured proposal with the exact threshold delta or regex change that would address the cluster. That proposal then flows through `/assess-proposal` — which checks that it changes only one variable, has a root-cause explanation, and does not regress the router's existing strong classifications — before reaching your approval prompt.

## When to use it

- Once `route-prompt.sh` has logged at least 100 classifications across at least 5 sessions — below that, the signal-to-noise ratio is too low and the skill will refuse to cluster.
- After the user reports that the router picked the wrong pattern repeatedly across a recognizable prompt class.
- As part of a periodic tuning cycle, run `/router-tune` followed by `/evolve router-tune` to process the proposals.

Do not use it for applying tuning changes directly — that is `/evolve`'s job. `/router-tune` produces proposals; it never modifies `route-prompt.sh` or `.claude/settings.json`.

## Best practices

- **Wait for sufficient data.** The minimum of 100 classifications across 5 sessions is not arbitrary — fewer observations make cluster boundaries unstable and proposals unreliable. If you are just starting out, let the router log accumulate before running this skill.
- **Read the proposal before running `/evolve`.** Each proposal artifact shows the exact threshold value or regex change, the number of miss-fires it addresses, and an impact estimate including regression risk. Review this before approving. A threshold drop from 0.75 to 0.70 seems small but may significantly increase LLM fallback frequency.
- **Treat regex proposals with extra care.** Modifying `route-prompt.sh` regex rules is more sensitive than adjusting a threshold. The `/assess-proposal` step checks for shell-injection risk, but you should also read the current regex and the proposed change side by side in the diff preview before approving.
- **Do not cluster below 3 occurrences.** The skill enforces this minimum — single miss-fires are noise. If you see a proposal addressing fewer than 3 cases, something went wrong with the clustering. Report it rather than approving.
- **Move thresholds in small steps.** The skill proposes at most ±0.10 per threshold change. Do not override this bound. The single-variable rule in `/assess-proposal` exists precisely to prevent large threshold jumps that are hard to attribute if they regress.

## How it improves your workflow

`/router-tune` closes the feedback loop on the `workflow` plugin's most user-facing component. Every time the router misclassifies a prompt, you pay a small friction cost — an extra command to override the recommendation. Over dozens of sessions, those costs add up. `/router-tune` converts that accumulated friction into structured proposals that can be assessed and landed in minutes, then measures their effect over subsequent sessions. The result is a router that improves with use rather than drifting further from your actual workflow patterns.

## Related

- [`/evolve`](evolve.md) — consumes the proposal artifacts this skill writes; run `/evolve router-tune` after `/router-tune` completes
- [`/commit-proposal`](commit-proposal.md) — lands approved proposals into `route-prompt.sh` or `.claude/settings.json`
- [`/rollback`](rollback.md) — reverses a router threshold or regex commit if it regresses classification quality
- [Architecture](../../architecture.md) — behavioral steering and self-evolution in the 8-component harness model
