---
name: run-evals-bench
description: Run comparative benchmarks for a skill — with-skill vs without-skill, N iterations each. Emits per-iteration benchmark.json with pass_rate/time/token mean+stddev+delta, and per-run grading.json with per-assertion evidence.
when_to_use: Reach for this when you want quantitative proof that a skill improves Claude's outputs — before publishing or after a description change. Do NOT use for structural eval validation — use /run-evals instead; do NOT use for rubric-weighted scoring without a benchmark context — use /score-rubric instead.
argument-hint: --skill <name> [--iterations N] [--baseline {none,prev}] [--out <dir>] [--mock]
scheduling: plugins/<plugin>/skills/<skill>/evals/evals.json exists and has ≥1 eval case
structural:
  - Resolve the target skill path and locate its evals/evals.json
  - For each eval case, run N sub-Claude calls with the skill injected (--add-dir) and N without
  - Per run, write outputs/, timing.json, then invoke score-rubric/scripts/score.py to produce grading.json
  - Aggregate per-iteration into benchmark.json with with_skill/without_skill/delta sections
  - Warn on assertions that have no signal (pass in both configs)
logical: iteration-N/benchmark.json exists for each requested iteration with with_skill.pass_rate, without_skill.pass_rate, and delta.pass_rate all present and in [0,1]
---

# /run-evals-bench — Comparative Skill Benchmark

Runs a skill's eval cases with and without the skill injected, producing quantitative pass-rate and latency deltas per iteration. Designed to generate evidence for publishing decisions and description-optimization loops.

## Inputs

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--skill <name>` | yes | — | Skill directory name (e.g. `ssl-audit`) or full path |
| `--iterations N` | no | 3 | Number of runs per configuration |
| `--baseline {none,prev}` | no | none | `prev` compares against the prior benchmark run |
| `--out <dir>` | no | `/tmp/<skill>-bench-<ts>/` | Workspace output directory |
| `--mock` | no | off | Synthetic mode — skips real sub-Claude calls for dev/CI use |

```bash
python3 plugins/evaluator/skills/run-evals-bench/scripts/bench.py \
  --skill ssl-audit \
  --iterations 3 \
  --baseline none \
  --out /tmp/ssl-bench/
```

## Workspace Layout

```
<out>/
└── iteration-N/
    ├── <eval-name>/
    │   ├── with_skill/
    │   │   ├── outputs/       raw model output per run
    │   │   ├── timing.json    {total_tokens, duration_ms}
    │   │   └── grading.json   per-assertion {passed, evidence}
    │   └── without_skill/
    │       ├── outputs/
    │       ├── timing.json
    │       └── grading.json
    └── benchmark.json         aggregated stats across all evals
```

## benchmark.json Schema

```json
{
  "skill": "ssl-audit",
  "iteration": 1,
  "with_skill":    {"pass_rate": 0.8, "time_seconds": 4.2, "tokens": 1200, "mean": 0.8, "stddev": 0.0},
  "without_skill": {"pass_rate": 0.4, "time_seconds": 3.9, "tokens": 1100, "mean": 0.4, "stddev": 0.0},
  "delta":         {"pass_rate": 0.4, "time_seconds": 0.3, "tokens": 100}
}
```

## grading.json Schema

```json
{
  "assertions": [
    {"text": "exits 0", "passed": true, "evidence": "exit code: 0"}
  ],
  "summary": {"passed": 1, "failed": 0, "total": 1, "pass_rate": 1.0}
}
```

Evidence for each assertion must be a quoted substring from `outputs/`.

## Execution Checklist

- [ ] Confirm `evals/evals.json` exists for the target skill (`/run-evals` to validate shape first)
- [ ] Run bench.py with desired `--iterations` and `--out`
- [ ] Check exit code: 0 = all done, 1 = at least one assertion always passes in both configs (no-signal WARN)
- [ ] Read `iteration-N/benchmark.json`; verify `delta.pass_rate > 0` for a useful skill
- [ ] Inspect `grading.json` evidence strings — confirm they are substrings of the actual output

## Known Failure Modes

- **No evals.json** — bench exits 1 with `evals.json not found`. Run `/run-evals` to validate first.
- **Sub-Claude timeout** — if a real `claude -p` call hangs, bench exits 1 after 120s per run. Reduce `--iterations` or add a shorter eval prompt.
- **Mock mode is for dev/CI only** — `--mock` writes deterministic synthetic outputs and completes in <5 seconds. It does not call the model; `grading.json` evidence reflects synthetic strings. Never publish benchmark results produced in `--mock` mode.
- **No-signal assertion** — if an assertion passes in both `with_skill` and `without_skill` configs, bench emits `WARN: assertion '<text>' has no signal (passes in both configs)` and continues. The delta row is still emitted; treat it as noise.
- **Performance budget** — with `--iterations 3` × 2 configs × 1 eval, expect ~6 sub-Claude calls. With 10 assertions and a slow prompt, a full bench may take 10+ minutes. Benchmarks are not session-startup hot paths.
