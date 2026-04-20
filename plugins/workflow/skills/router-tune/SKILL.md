---
name: router-tune
description: Analyze router classification history, cluster miss-fires, emit a proposal artifact tweaking route-prompt.sh thresholds or regex rules. Feeds /evolve. First concrete end-to-end SEPL loop in Forge Studio.
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# /router-tune — Router Self-Tuning

The router (`plugins/workflow/hooks/route-prompt.sh`) logs every classification to `/tmp/claude-router-<session_id>/classifications.jsonl`. This skill turns that history into a proposal artifact consumable by `/evolve`.

Chosen as the first concrete SEPL loop because:

- The resource is numeric (`env/WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD`) or a small regex — low blast radius on commit.
- The signal is machine-readable — no model opinion needed.
- Rollback is trivial — snapshot a threshold value.

## Flow

### Step 1 — Gather traces

```bash
find /tmp/claude-router-* -name classifications.jsonl -mtime -30 -print0 | xargs -0 cat > /tmp/router-tune-input.jsonl
wc -l /tmp/router-tune-input.jsonl
```

Minimum 100 classifications across at least 5 sessions. Below that, abort and tell the user to gather more data.

### Step 2 — Detect miss-fires

Two signals:

**A. Low-confidence classifications followed by manual `/orchestrate`**

Same session, within 3 turns: router emitted `route=X` with `confidence<0.75`, then user invoked `/orchestrate <Y>` with `Y != X`. Count these per (shell-emitted-route, user-chosen-route) pair.

**B. Router emitted `route=none` on prompts where user then dispatched work**

Session includes a `route=none` classification, then a subagent invocation within 2 turns. Count per prompt regex fragment (first 3 words).

Use `jq` / `awk` to aggregate — no LLM needed.

### Step 3 — Cluster

Group miss-fires into at most 3 clusters:

| Signal | Proposal kind |
|---|---|
| Consistent override X → Y with moderate confidence (0.6–0.75) | Lower threshold: `env/WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD` from 0.75 → 0.70 |
| Specific prompt pattern keeps hitting `route=none` then dispatching Y | Add regex to `hooks/workflow/route-prompt.sh` Priority-N block for Y |
| Route X fires often with high confidence but user never keeps it | Narrow the regex — add an exclusion |

### Step 4 — Emit proposal artifacts

For each cluster, write `.claude/lineage/proposals/<YYMMDD>-router-<slug>-v<N>.md`:

```markdown
# Proposal: <short title>

**Resource:** env/WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD
**Current version:** v<N-1> (value: 0.75)
**Target version:** v<N> (value: 0.70)

## Rationale

Detected <count> miss-fires across <sessions> sessions where shell confidence
landed in 0.60–0.75 and user overrode via /orchestrate. Pattern:
<X> → <Y>, e.g. "<example prompt snippet>".

## Proposed change

Change env.WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD: 0.75 → 0.70 (in .claude/settings.json).

## Impact

- Token cost:     negligible (env var, not loaded into context)
- Behavior:       ~<count>/<total> prior low-confidence classifications would now escalate to LLM fallback instead of sticking with shell verdict
- Regression risk: LLM fallback adds one Haiku call per escalation (~30-50 tokens)

## Trigger

router-tune cluster <cluster-id>. Input traces: /tmp/router-tune-input.jsonl.
```

For regex proposals (hooks/workflow/route-prompt.sh modifications), show the current regex + proposed regex in the `## Proposed change` section as a unified diff. Note: committing a regex change means editing `route-prompt.sh`, which is a sensitive shell script — `/assess-proposal` must check for shell-injection risk before passing.

### Step 5 — Report

```
router-tune: <N> proposals written to .claude/lineage/proposals/
Next: /evolve router-tune
```

## Do NOT

- Do not write ledger entries directly — that's `/evolve`'s job.
- Do not modify `route-prompt.sh` or `.claude/settings.json` here. Proposal only.
- Do not cluster below 3 occurrences — single miss-fires are noise.
- Do not propose threshold changes below 0.50 or above 0.95 in one step. Single-variable rule: move at most ±0.10 per proposal.
