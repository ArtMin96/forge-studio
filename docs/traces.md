# Execution Traces

## What Are Traces?

Traces are structured records of every action Claude Code takes during a session — commands executed, files modified, errors encountered. They're stored as JSONL (one JSON object per line) in `~/.claude/traces/`, searchable with `grep` or `jq`.

The traces plugin is a **feedback sensor** (computational) that observes agent behavior silently and records it for later analysis. It adds zero tokens to the conversation — all output goes to files, never to the model's context.

## Why Traces Matter

The Meta-Harness paper (arXiv 2603.28052) ran an ablation study comparing agent performance with full execution traces vs compressed summaries:

| Access Level | Median Accuracy | Relative Improvement |
|-------------|----------------|---------------------|
| Compressed summaries only | 34.9 | baseline |
| Full execution traces | 50.0 | **+43%** |

The insight: when an agent can see exactly what it did (and what failed), it makes dramatically better decisions in subsequent iterations. Summaries lose critical details — the exact error message, the specific flag that caused a failure, the file path that was wrong.

NeoSigma extended this further with a self-improving loop, demonstrating **39.3% improvement** on Tau3 bench by mining traces for failure patterns and evolving the harness automatically — with zero model upgrades.

## How It Works

### Collection (Automatic)

Four hooks fire silently during every session:

```text
Session Start
  │
  ├── User submits prompt ──► UserPromptSubmit ──► collect-user-turn.sh
  │                            Records: prompt length, session id (no content stored)
  │
  ├── User runs commands ──► PostToolUse:Bash ──► collect-bash-trace.sh
  │                            Records: command, exit code, output preview (500 chars)
  │
  ├── User writes/edits ──► PostToolUse:Write|Edit ──► collect-file-trace.sh
  │                            Records: file path, tool name (Write vs Edit)
  │
  └── Session ends ────────► SessionEnd ──► session-summary.sh
                               Aggregates: total commands, errors, files modified
```

All four hooks:
- Exit with code 0 (info only, never blocks)
- Have a 5-10 second timeout (fail silently if slow)
- Can be disabled via `FORGE_TRACES_ENABLED=0`
- Write to files, never to model context (zero token cost)

### Storage Format

Traces are stored as JSONL files in `~/.claude/traces/`:

```text
~/.claude/traces/
  2026-04-06-a1b2c3d4.jsonl    ← one file per day per working directory
  2026-04-05-a1b2c3d4.jsonl
  2026-04-05-e5f6g7h8.jsonl    ← different project same day
```

Filename format: `{date}-{directory-hash}.jsonl`

### Entry Types

**Bash trace** — recorded after every shell command:
```json
{
  "timestamp": "2026-04-06T14:23:01Z",
  "type": "bash",
  "command": "php artisan test --compact --filter=UserTest",
  "exit_code": "1",
  "output_preview": "FAIL Tests\\Feature\\UserTest > it can create...",
  "cwd": "/home/user/project"
}
```

**File trace** — recorded after every Write or Edit:
```json
{
  "timestamp": "2026-04-06T14:23:15Z",
  "type": "file",
  "tool": "Edit",
  "file_path": "/home/user/project/app/Models/User.php",
  "cwd": "/home/user/project"
}
```

**Session summary** — recorded at session end:
```json
{
  "timestamp": "2026-04-06T16:45:00Z",
  "type": "session_end",
  "bash_commands": 47,
  "file_operations": 23,
  "errors": 5,
  "unique_files_modified": 8,
  "cwd": "/home/user/project"
}
```

## Analysis Skills

### `/trace-stats` — Quick Overview

Shows a table of recent sessions with command counts, error rates, and files modified. Use for a pulse check: "Am I making more errors than usual?"

```text
## Session Traces (last 10 sessions)

| Date       | Commands | Errors | Files Modified | Error Rate |
|------------|----------|--------|----------------|------------|
| 2026-04-06 | 47       | 5      | 8              | 10.6%      |
| 2026-04-05 | 32       | 2      | 12             | 6.3%       |
```

### `/trace-clarification` — Clarification-Timing Lens

Per-session ratio of how much work ran before the first mid-session user turn arrived. Reads `user_turn` entries from the JSONL trace and counts preceding `bash` / `file` actions. High ratios indicate clarification arrived after most of the trajectory was already committed — work that may not survive the clarified intent.

```text
session                | first_clarify_at_action | actions_before | total | waste_ratio
-----------------------|-------------------------|----------------|-------|------------
2026-05-10-a1b2c3d4    | 18                      | 17             | 24    | 0.71
2026-05-09-a1b2c3d4    | 4                       | 3              | 19    | 0.16
```

Use as a follow-up to `/trace-stats` when sessions look noisy but the per-command stats look clean — the cost may be timing-shaped, not error-shaped.

### `/trace-review` — Pattern Analysis

Deeper analysis across 5 recent sessions. Identifies:
- **Recurring failures**: commands that fail repeatedly (candidates for hooks or rules)
- **File hotspots**: files modified most often (candidates for refactoring or testing)
- **Wasted turns**: commands that never produce useful output
- **Session health trends**: is the error rate improving or degrading?

### `/trace-evolve` — Harness Evolution

The most powerful analysis skill. Inspired by NeoSigma's self-improving loop:

```text
┌─────────────────────────────────────────────────────────┐
│                   /trace-evolve                         │
│                                                         │
│  Phase 1: Failure Mining                                │
│  ├── Read 2 weeks of trace files                        │
│  ├── Filter for non-zero exit codes + error keywords    │
│  └── Build structured failure records                   │
│                                                         │
│  Phase 2: Failure Clustering                            │
│  ├── Group by root cause mechanism (not symptoms)       │
│  ├── Cluster types: tool misuse, stale context,         │
│  │   environment, test regression, permission, workflow  │
│  └── Prioritize by frequency × sessions affected        │
│                                                         │
│  Phase 3: Propose Changes                               │
│  ├── For each cluster (top 5), propose ONE of:          │
│  │   ├── New rules.d/ rule (behavioral pattern)         │
│  │   ├── New hook condition (tool-use boundary)         │
│  │   ├── Skill enhancement (workflow gap)               │
│  │   └── No change (one-off / environmental)            │
│  └── Include: token impact, regression risk             │
│                                                         │
│  Phase 4: Report                                        │
│  └── Structured output with clusters, proposals,        │
│      and prioritized next steps                         │
│                                                         │
│  ⚠ Analyze + propose only. Does NOT modify files.       │
└─────────────────────────────────────────────────────────┘
```

**When to run:** Weekly, or after a frustrating session where Claude kept making the same mistake. Not automated — you decide when the data is worth analyzing.

**Minimum thresholds:** Won't propose changes for one-off failures. Requires 3+ occurrences across 2+ sessions before clustering.

## How Traces Improve the Harness

Traces create a **feedback loop** that closes the gap between static harness configuration and dynamic agent behavior:

```text
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│              │     │              │     │              │
│   Harness    │────►│    Agent     │────►│   Traces     │
│  (rules,     │     │  (executes   │     │  (records    │
│   hooks,     │     │   tasks)     │     │   actions)   │
│   skills)    │     │              │     │              │
│              │     │              │     │              │
└──────┬───────┘     └──────────────┘     └──────┬───────┘
       │                                         │
       │         ┌──────────────┐                 │
       │         │              │                 │
       └─────────┤ /trace-evolve├─────────────────┘
                 │  (analyzes   │
                 │   failures,  │
                 │   proposes   │
                 │   changes)   │
                 │              │
                 └──────────────┘
```

Without traces, harness improvements are reactive — you notice a problem, you manually debug, you add a rule. With traces, improvements are **systematic** — failure patterns emerge from data, not anecdotes.

## Failure Attribution

When a regression surfaces — a test that passed last week fails today, or behavior changed without an obvious cause — the key question is: *which change introduced it?*

With the v2 manifest schema (arXiv:2605.18747 §5.2.4), every manifest entry declares `verifier_obligations`: shell commands that must exit 0 to confirm the change held up. Attribution becomes mechanical: walk recent entries in reverse-chronological order, re-run each entry's verifier obligations, and the first one that fails today (but passed at write-time) is the primary suspect.

arXiv:2605.18747 §3.5.2 describes this as the Evolution Agent's *diagnose stage*. §5.1.1 reports that production attribution accuracy under naive approaches (Who&When, AgenTracer baselines) sits at only 14–53%; structured verifier replay closes that gap substantially.

### End-to-end example

A regression is reported today. The last 5 manifest entries are:

```
chg-AAA  2026-05-14  agent:generator  verifier: python3 -c "..."    evidence: checks_run: [json-parse]
chg-BBB  2026-05-15  agent:generator  verifier: test -f plugins/x/SKILL.md  evidence: checks_run: [hook-exit]
chg-CCC  2026-05-16  agent:generator  (no evidence_bundle)
chg-DDD  2026-05-17  agent:generator  verifier: bash count.sh . | grep ...  evidence: checks_run: [count-check]
chg-EEE  2026-05-18  agent:generator  verifier: test -f README.md            evidence: checks_run: [smoke]
```

`/failure-attribute` walks them newest-first:

1. `chg-EEE` — evidence non-empty; verifier passes → skip
2. `chg-DDD` — evidence non-empty; verifier passes → skip
3. `chg-CCC` — **no evidence_bundle** → flagged priority 1 (suspect-by-default), reason: `no_evidence`
4. `chg-BBB` — evidence non-empty; `test -f plugins/x/SKILL.md` fails (file was renamed) → flagged priority 2, reason: `verifier_failed`
5. `chg-AAA` — evidence non-empty; verifier passes → skip

**Primary suspect**: `chg-CCC` (priority 1 outranks priority 2). The missing evidence is itself the signal — entries with no declared checks are the highest-risk candidates.

```bash
bash plugins/traces/skills/failure-attribute/scripts/attribute.sh \
  .claude/evolution/change_manifest.jsonl 20
```

Output excerpt:
```json
{
  "primary_suspect": {
    "id": "chg-CCC",
    "agent": "generator",
    "ts": "2026-05-16T09:00:00Z",
    "reason": "no_evidence",
    "priority": 1
  }
}
```

### Empty-evidence predicate

Entries are flagged suspect-by-default — priority above any verifier-failure — when:

| Shape | Flagged |
|-------|---------|
| `evidence_bundle` key absent | yes |
| `evidence_bundle: null` | yes |
| `evidence_bundle: {}` | yes |
| `evidence_bundle.checks_run` absent, null, or `[]` | yes |

The rationale: an entry that made no checkable claim provides no basis for clearing itself. Flagging it forces the engineer to either add evidence retroactively or accept it as the most likely suspect.

### Integration with `/rollback`

`/rollback` runs `/failure-attribute` before asking which version to revert. If a `primary_suspect` is found, it is shown as the suggested rollback target. The user confirms or overrides.

## Token Cost

**Zero.** Trace hooks write to files, not to the model's context window. The only token cost comes from invoking the analysis skills (`/trace-stats`, `/trace-review`, `/trace-evolve`, `/failure-attribute`), and those are on-demand.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `FORGE_TRACES_ENABLED` | `1` | Set to `0` to disable all trace collection |
| Hook timeouts | 5-10s | Hooks fail silently if they take too long |
| Output preview | 500 chars | Bash output is truncated to prevent large trace files |
| File rotation | Manual | Old trace files can be deleted without consequence |

## Research Background

| Source | Finding | How Traces Applies |
|--------|---------|-------------------|
| Meta-Harness (2026) | Full traces → 43% improvement over summaries | Collect everything, analyze later |
| NeoSigma (2026) | Self-improving loop → 39.3% improvement | `/trace-evolve` implements the analysis phase |
| Bockeler (2026) | Computational feedback > inferential feedback | Trace collection is computational (deterministic, cheap) |
| HumanLayer (2026) | Silent success, verbose failure | Traces are completely silent — zero context pollution |
