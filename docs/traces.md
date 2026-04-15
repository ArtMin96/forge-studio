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

Three hooks fire silently during every session:

```
Session Start
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

All three hooks:
- Exit with code 0 (info only, never blocks)
- Have a 5-10 second timeout (fail silently if slow)
- Can be disabled via `FORGE_TRACES_ENABLED=0`
- Write to files, never to model context (zero token cost)

### Storage Format

Traces are stored as JSONL files in `~/.claude/traces/`:

```
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

```
## Session Traces (last 10 sessions)

| Date       | Commands | Errors | Files Modified | Error Rate |
|------------|----------|--------|----------------|------------|
| 2026-04-06 | 47       | 5      | 8              | 10.6%      |
| 2026-04-05 | 32       | 2      | 12             | 6.3%       |
```

### `/trace-review` — Pattern Analysis

Deeper analysis across 5 recent sessions. Identifies:
- **Recurring failures**: commands that fail repeatedly (candidates for hooks or rules)
- **File hotspots**: files modified most often (candidates for refactoring or testing)
- **Wasted turns**: commands that never produce useful output
- **Session health trends**: is the error rate improving or degrading?

### `/trace-evolve` — Harness Evolution

The most powerful analysis skill. Inspired by NeoSigma's self-improving loop:

```
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

```
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

## Token Cost

**Zero.** Trace hooks write to files, not to the model's context window. The only token cost comes from invoking the analysis skills (`/trace-stats`, `/trace-review`, `/trace-evolve`), and those are on-demand.

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
