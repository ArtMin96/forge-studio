# Memory Curse Applications

Three forge-studio artifacts that translate findings from *The Memory Curse: How Expanded Recall Erodes Cooperative Intent in LLM Agents* (Liu et al., arXiv:2605.08060v1, May 2026) into single-user Claude Code workflows.

| Artifact | Plugin | Auto-fires? | Daily value |
|---|---|---|---|
| `/reasoning-tilt` skill | `traces` | No — manual | Diagnostic, low frequency |
| `/forward-briefing` skill + `surface-progress.sh` extension | `long-session` | Hook auto-fires on SessionStart | High — every new session |
| Rule 65 `deliberation-suppression` | `behavioral-core` | Yes — injected every prompt | Subtle, ambient |

---

## Background: What The Paper Found

The paper studies 7 LLMs × 4 social-dilemma games × 9 history lengths × 3 seeds (378,000 reasoning traces, 500 rounds each). Three findings transfer to single-user dev workflows:

| Finding | Evidence in paper | Transferable mechanism |
|---|---|---|
| **F2: Content, not length, drives long-context degradation.** At fixed prompt length HL=80, replacing 78 of 80 history rounds with synthetic cooperative records lifted Llama-3.3-70B cooperation 6.9% → 97.43%. | §4.5 + Appendix Table 13 | The *framing* of injected history shapes the model's posture, independent of token budget. |
| **F3: The mechanism is erosion of forward-looking reasoning, not rising paranoia.** Cooperative-language frequency collapses as HL grows; defensive-language frequency stays roughly flat. Forward-looking ratio drops 0.504 → 0.340 between immune and cursed regimes. | §4.3, §D.4, Appendix Table 8 | Lexical bias toward "what failed" vs "what's next" is measurable in CoT-style reasoning traces. |
| **F4: Chain-of-Thought amplifies the curse when context is polluted.** At HL=80, Llama-3.3-70B cooperation: 100% with no reasoning, 6.9% with CoT (Δ = −93.1 pp). | §4.6 + Appendix Table 12 | Explicit deliberation over degraded context can amplify the degradation rather than correct it. |

**Domain caveat.** The paper's experimental domain is multi-agent social dilemmas (Prisoner's Dilemma, Trust Game, Public Goods, Traveler's Dilemma). The cooperation-game framing — payoffs, grudge-holders, contagion — does *not* apply to single-user Claude Code. Only the three mechanisms above transfer. The LoRA fine-tuning intervention from §4.2 is intentionally excluded.

---

## `/reasoning-tilt` — Lexical Tilt Diagnostic

**Plugin:** `traces` · **Path:** `plugins/traces/skills/reasoning-tilt/` · **Auto-fires:** no

### When to use

Reach for this when you suspect a long session has drifted from forward planning into reactive debugging. The skill scores a JSONL trace file for the ratio of forward-looking tokens (`next`, `try`, `plan to`, `I'll`, `should work`) to history-following tokens (`blocked`, `stuck`, `failed again`, `can't`, `won't`). A ratio below 0.40 echoes the paper's cursed regime (0.340).

Do **not** reach for it for numeric session summaries — that's `/trace-stats`. Do **not** reach for it for structural failure clustering — that's `/trace-review`. This skill answers a different question: *is my session's tone forward-looking or history-following?*

### How it works

`scripts/score.sh` walks a `.jsonl` trace file under `~/.claude/traces/` and tallies whole-word matches against `scripts/vocab.tsv` (a small, paper-anchored two-class vocabulary). Output:

```text
Trace: ~/.claude/traces/2026-05-12T10-00-00.jsonl
Forward tokens: 47
History tokens: 73
Forward ratio: 0.39
tilt:history
```

Three classifications:
- `tilt:forward` (ratio ≥ 0.60) — session is anchored on next steps.
- `tilt:balanced` (0.40 ≤ ratio < 0.60).
- `tilt:history` (ratio < 0.40) — session is anchored on past failure.

### Usage

```bash
# Default: scores the most recent trace
/reasoning-tilt

# Or pass an explicit trace file
bash plugins/traces/skills/reasoning-tilt/scripts/score.sh ~/.claude/traces/<id>.jsonl
```

### Limitations

- Traces don't contain raw model reasoning — only `command`, `output_preview`, and user-turn strings. The metric is a *proxy*, not a direct read of CoT.
- A single-session signal is noisy. The paper's metric works at population scale (378k traces). Trust the direction more than the absolute value.
- The vocabulary is small and English-only. Multilingual sessions will under-count.

---

## `/forward-briefing` — Forward-Framed Session Briefing

**Plugin:** `long-session` · **Path:** `plugins/long-session/skills/forward-briefing/` · **Auto-fires:** companion hook does, skill itself is manual

### When to use

Reach for this at session end (or before a `/compact`) when the next session needs a clean handoff. The skill reads the last 5 entries of `claude-progress.txt` and produces `.claude/forward-briefing.md` — a derived view that re-presents accumulated blockers as open questions and surfaces next-steps first.

The append-only `claude-progress.txt` is **never** edited; the briefing is a separate artifact, regenerated whenever you re-invoke the skill.

Do **not** reach for it to write the progress log itself — that's `/progress-log`. Do **not** reach for it for a full session briefing including spec, features, and git state — that's `/session-resume`. `/forward-briefing` is narrower: it only transforms the log's tone for next-session priming.

### How it works

The skill reads the last 5 progress entries and emits three sections to `.claude/forward-briefing.md`:

- **`## Last session left at`** — one-line snapshot drawn from the most recent `Done:` + `In progress:` blocks.
- **`## Direct next steps`** — verbatim `Next:` items from the last 5 entries, oldest first, deduplicated.
- **`## Open questions`** — each `Blockers:` item re-framed as a question or probe. Facts preserved; framing rewritten.

Example transformation:

```text
# Input (claude-progress.txt tail)
Blockers:
  - Still failing on rate-limit test after three attempts

# Output (forward-briefing.md)
## Open questions
- What changed between the third attempt and the test's last-passing commit? (next: bisect)
```

The companion hook `plugins/long-session/hooks/surface-progress.sh` auto-fires at SessionStart. If `.claude/forward-briefing.md` exists and is **newer** than `claude-progress.txt`, the hook prefers it over the raw last-3-entries tail. If the briefing is absent or stale, the hook falls back to the existing tail behaviour — zero regression.

### Usage

```bash
# End of session: refresh the briefing
/forward-briefing

# (Optional) commit the log alongside the briefing
git add claude-progress.txt && git commit -m "session: progress"

# Next session: surface-progress.sh injects the briefing automatically
```

### Why the append-only invariant matters

`claude-progress.txt` is the durable source of truth across sessions. Editing it in place — even with good intentions — would lose the audit trail. The briefing is a regeneratable view, not a replacement. If a briefing turns out to be wrong, regenerate it; the log remains intact.

### Empirical anchor

Paper §4.5 + Appendix Table 13 prove that at *fixed* context length, swapping accumulated negative content for forward-framed content restores cooperative behaviour. The skill applies the same content-shift idea to dev-session resume content. The mechanism is the transferable bit — the cooperation-game framing is not.

### Structured briefing as compaction mitigation

The `/forward-briefing` skill addresses tone. A separate mechanism — the `forward-briefing.sh` PreCompact hook — addresses *state reconstruction*. arXiv:2605.18747 §3.2.6 shows that bare prose summaries at compaction boundaries silently drop the highest-signal items (failing test names, stack frames, suspect file:line references). The hook emits a YAML document with four structured fields (`open_failures`, `recent_edits`, `pending_verifications`, `belief_snapshots`) written to `.claude/state/forward-briefing-<session-id>.yaml`. The companion `post-compact-recovery.sh` PostCompact hook reads that file and re-injects it as the first model-visible turn, giving the post-compact session concrete data instead of prose narration. Rule 65 addresses a different mechanism — it suppresses deliberation that would amplify failure context already in the window; the structured briefing addresses what data enters the window in the first place. Both are necessary because the tone-of-content problem (Rule 65) and the state-loss problem (structured briefing) are orthogonal failure modes. See [`docs/compaction-briefing.md`](compaction-briefing.md) for the full user guide.

---

## Rule 65 — Deliberation Suppression

**Plugin:** `behavioral-core` · **Path:** `plugins/behavioral-core/hooks/rules.d/65-deliberation-suppression.txt` · **Auto-fires:** yes — injected into every UserPromptSubmit

### What it does

The rule primes Claude to ask whether more deliberation is actually helping before reaching for `/ultrathink`, `/devils-advocate`, `/grill-me`, or extended-thinking blocks — *when the session has accumulated consecutive failures or repeated dead-ends*.

It is descriptive, not enforcing. There is no hook that blocks the deliberation skills; the rule is a behavioral nudge that lives alongside the other 15 rules in `hooks/rules.d/`.

### Why

Paper §4.6 + Appendix Table 12 show that under polluted context (HL=80 with accumulated defection signals), explicit CoT can flip a 100%-cooperation policy to 6.9% — a −93.1 pp drop for Llama-3.3-70B. The mechanism: explicit reasoning over a context full of failures elaborates and ratifies the failure pattern instead of escaping it.

For long degraded Claude Code sessions, the analogous failure mode is reaching for `/ultrathink` or `/devils-advocate` when the session is already stuck. Deeper deliberation over the same stuck-state context tends to elaborate the stuck-ness, not transcend it. The empirical case for "less reasoning is sometimes better" is the no-reasoning ablation in Appendix G.

### Practical effect

When a session has visibly accumulated failures (≥ N consecutive failed tool calls, repeated dead-ends on the same file), the rule's presence in the prompt nudges toward:

- Direct action and smaller iterative changes.
- A different angle (different file, different test, different command), not a deeper analysis of the same angle.
- Stopping and asking the user before invoking deliberation skills.

It is one paragraph, no caps, no enforcement. Compliance is statistical, not absolute.

### Empirical anchor

```text
Research shows that explicit chain-of-thought reasoning over degraded
context can amplify the degradation rather than correct it — at high
history-length with accumulated defection signals, adding CoT flipped
a 100%-cooperation baseline to 6.9% (arXiv:2605.08060v1 §4.6).
```

---

## Honest Assessment

| Artifact | Likely daily value | Caveat |
|---|---|---|
| `/forward-briefing` + hook | High. Every SessionStart gets a re-framed briefing without you doing anything. | The skill itself is manual — you have to refresh the briefing at session end for the hook to surface it next time. |
| Rule 65 | Subtle. Ambient nudge across many prompts. | No way to measure compliance directly; effect is statistical. |
| `/reasoning-tilt` | Low. Diagnostic, requires explicit invocation, single-session signal is noisy. | Vocabulary is small + English-only. Useful for retroactive review, not real-time steering. |

If forced to keep only one, keep `/forward-briefing` — the hook auto-half is where the leverage is.

---

## References

- **Paper:** Liu et al., *The Memory Curse: How Expanded Recall Erodes Cooperative Intent in LLM Agents*, arXiv:2605.08060v1, May 2026.
- **Sibling docs:** [traces.md](traces.md) — the underlying trace-collection plugin. [agentic-workflow.md](agentic-workflow.md) — orchestrator that uses `/forward-briefing` output indirectly via `surface-progress.sh`.
- **Source plan:** authoring artifact for this work was `.claude/plans/memory-curse-forge-application.md` (gitignored; per-session).
