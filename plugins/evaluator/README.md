# evaluator

The critic. Gates "done" claims, runs adversarial review on changes, and audits whether prior predictions held up.

## What it does

Models declare success too easily. This plugin separates verification from implementation — every "done" passes through `/verify`, every self-evolution proposal passes through `/assess-proposal` (run in a forked subagent so the critic can't be primed by the implementer), and every reference is cross-checked against the actual repo before it reaches a commit message.

## When to use

You always want it on. The hooks are passive — they only fire on `TaskCompleted`, `PostToolUse`, and pre-commit. Skills are on-demand.

## How it works

```text
 TaskCompleted        ──► task-completion-gate.sh   demand evidence before allowing "done"
 PostToolUse (Edit)   ──► test-nudge.sh             remind to test after edits
                          php-static-analysis.sh    PHP project: run on relevant edits
                          js-static-analysis.sh     JS/TS project: run on relevant edits
 PostToolUse (Bash)   ──► test-nudge-reset.sh       clear nudge after a test command
                          filter-test-output.sh     compress verbose test logs
 PreToolUse  (Bash)   ──► pre-commit-gate.sh        block commit when verification was skipped
```

The forked `adversarial-reviewer` agent runs `/assess-proposal` and `/challenge` in a subagent that cannot see the implementer's chain of thought.

## Skills

| Skill | Purpose |
|---|---|
| `/verify` | Verification gate. Runs the listed commands, captures actual output, compares against `.claude/features.json` or `/contract`. Refuses "done" without evidence |
| `/healthcheck` | One-command quality snapshot. Auto-detects PHP and JS/TS, runs the respective pipeline |
| `/assess-proposal` | Adversarial review of a self-evolution proposal. Emits pass/fail against four criteria |
| `/challenge` | Two-stage critique — self-review against the diff, then git-history verification |
| `/devils-advocate` | Strongest counter-case before committing — structured tradeoff with opposing evidence |
| `/grill-me` | Stress-test a plan. Walks decision branches, refuses to move on until shared understanding is reached |
| `/postmortem` | Convert a fix into a durable lesson. Root cause + classification + "could a hook catch this?" |
| `/prediction-audit` | Join SEPL proposal predictions against post-commit traces. Reports per-resource error |
| `/verify-refs` | Cross-check claimed file paths, function names, URLs against the actual repo. Catches hallucinated references |
| `/gate-report` | Single consolidated view of every quality warning hooks raised this session |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `TaskCompleted` | task-completion-gate | Demand proof before allowing "done" |
| `PostToolUse` (`Edit\|Write`) | test-nudge | Nudge testing after edits |
| `PostToolUse` (`Edit\|Write`) | php-static-analysis, js-static-analysis | Run static analysis on relevant edits |
| `PostToolUse` (`Bash`) | test-nudge-reset | Clear the nudge once a test command runs |
| `PostToolUse` (`Bash`) | filter-test-output | Compress verbose test logs |
| `PreToolUse` (`Bash`) | pre-commit-gate | Block commit when verification was skipped |

## Agents

`adversarial-reviewer.md` — read-only critic forked into a subagent for assessments.

## Disable

`/plugin disable evaluator@forge-studio`. You lose the verification gate — nothing else stops you from claiming a task done without proof.
