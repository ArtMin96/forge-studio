# evaluator

The verification surface. Every "done" claim passes through `/verify` before it counts. The evaluator owns static analysis gates, adversarial review, and a new orchestrator-imposed verification nudge — `auto-verify.sh` — that fires automatically after generator and reviewer subagents stop, so verification is not discretionary (per CAAF 2604.17025 p.39).

## What it does

Models declare success too easily. This plugin separates verification from implementation: every "done" passes through `/verify`, every self-evolution proposal passes through `/assess-proposal` (run in a forked subagent so the critic cannot be primed by the implementer), and every reference is cross-checked against the actual repo before it reaches a commit message. The hooks are passive — most fire automatically; you do not have to remember to trigger them.

## When to use

You always want it on. The hooks fire on `TaskCompleted`, `PostToolUse`, `SubagentStop`, and pre-commit. Skills are on-demand.

## How it works

```text
 TaskCompleted        ──► task-completion-gate.sh   demand evidence before allowing "done"
 PostToolUse (Edit)   ──► test-nudge.sh             remind to test after edits
                          php-static-analysis.sh    PHP project: run PHPStan on .php changes
                          js-static-analysis.sh     JS/TS project: run ESLint/tsc on .js/.ts/.tsx changes
 PostToolUse (Bash)   ──► test-nudge-reset.sh       clear the nudge counter once a test command runs
                          filter-test-output.sh     compress verbose test logs
 PreToolUse  (Bash)   ──► pre-commit-gate.sh        block commit when /verify has not been run
 SubagentStop         ──► auto-verify.sh            orchestrator-imposed PASS/FAIL gradient on evidence state
```

The forked `adversarial-reviewer` agent runs `/assess-proposal` and `/challenge` in a subagent that cannot see the implementer's chain of thought.

## Skills

| Skill | Command | What it does | When to use |
|-------|---------|-------------|-------------|
| verify | `/verify` | Runs the verification commands from the active plan's Contract section, captures actual output (exit codes + truncated stdout), and compares against `.claude/features.json`. Refuses to mark done without evidence — closes the "I think it works" gap. On FAIL, emits a Structured Semantic Gradient (Dimension/Direction/Magnitude — same schema as `auto-verify.sh`) per failed criterion. | Before committing, merging, or telling the user a task is fixed |
| healthcheck | `/healthcheck [--quick\|--full]` | One-command quality snapshot. Auto-detects PHP (composer + pest + pint + phpstan) and JS/TS (npm + tests + lint + typecheck) and runs the relevant pipeline; returns a single PASS/WARN/FAIL summary | Before committing or opening a PR when you want a project-wide health signal without specifying individual commands |
| run-evals | `/run-evals <eval-file-or-glob>` | Validates per-skill eval JSON files for structural conformance (required fields, shape, types) and emits a checklist of declared expectations | When adding a new `evals/evals.json` case or before handing fixtures to a judge runner |
| run-evals-bench | `/run-evals-bench --skill <name>` | Comparative benchmark: runs a skill N times with and without the skill active, reports pass_rate, time, and token cost mean+stddev+delta | When you want quantitative proof that a skill improvement is real before publishing |
| challenge | `/challenge` | Two-stage critique: Stage 1 self-review against the diff, Stage 2 git-history verification. Forks to a general-purpose agent so the critique is independent of the implementation context | After finishing complex or security-sensitive features where "tests pass" is not enough proof |
| devils-advocate | `/devils-advocate <decision>` | Strongest counter-case against a design decision. Produces a structured tradeoff analysis with opposing evidence | During architecture choices or before locking in a refactor approach when consensus feels too easy |
| grill-me | `/grill-me` | Structured interview that walks every branch of a design's decision tree, recommends an answer for each question, and refuses to move on until shared understanding is reached. Also invoked automatically when the active plan has unresolved goal or context questions | Before locking a non-trivial design or handing a plan to `/dispatch` |
| postmortem | `/postmortem [description]` | Root-cause analysis of a recent fix: classifies the bug type (logic/race/state/env/integration), asks "could a hook have caught this?", and produces a prevention recommendation | After a fix is verified and merged, to convert the failure into a durable lesson |
| prediction-audit | `/prediction-audit` | Joins past SEPL proposal predictions against post-commit trace observations; reports per-resource prediction error (accurate / over-estimate / under-estimate / insufficient-data) | Monthly, after several SEPL commits, to check whether `/assess-proposal` impact estimates hold up |
| score-rubric | `/score-rubric <rubric.json> <scores.json>` | Aggregates weighted criterion scores into a normalised result in [0,1] with a per-criterion breakdown | When you have a rubric definition and raw criterion scores and need a validated aggregate |
| gate-report | `/gate-report` | Consolidated view of every quality warning hooks raised this session, grouped by severity | Right before a commit or PR, or after a long session to check whether anything failed silently |
| verify-refs | `/verify-refs` | Cross-checks file paths, function names, and URLs claimed in the prior turn against the actual repo | After drafting any summary, PR description, or commit message that names specific files or symbols |
| assess-proposal | `/assess-proposal <proposal-path>` | Adversarial review of a self-evolution proposal: scores against the SEPL rubric (severity, evidence, alignment, risk) and emits accept / reject / revise. Runs in a forked subagent | Immediately after `/evolve` writes a proposal artifact, before user approval or `/commit-proposal` |
| optimize-description | `/optimize-description --skill <path> --corpus <queries.json>` | 5-iteration description-optimization loop: splits a query corpus 60/40 train/val, measures trigger rates, and proposes the description with the highest validation pass rate | When a skill's description causes false-positive or false-negative trigger rates and you have a representative query corpus |

## Hooks

| Hook | Event | Matcher | When it fires | What it does |
|------|-------|---------|--------------|-------------|
| `auto-verify.sh` | `SubagentStop` | (none; filters internally on `*generator*` and `*reviewer*` agent types) | After a generator or reviewer subagent stops | Orchestrator-imposed verification nudge. Reads `.claude/gate/features.json` and emits a structured gradient to stderr: `[auto-verify] Dimension=gate-features  Direction=PASS\|FAIL  Magnitude=<short remediation>`. PASS when the gate file lists at least one entry and every entry has `passed: true`; FAIL otherwise. Exit 0 on PASS, 1 on FAIL. Never exits 2 — blocking SubagentStop breaks dispatch. Set `FORGE_AUTO_VERIFY=0` to disable |
| `pre-commit-gate.sh` | `PreToolUse` | `Bash` | Before a `git commit` command | Checks whether `/verify` has been run (via `~/.claude/evaluation-gate.flag`) against the current plan. If the plan is recent (<24h) and the gate has not been cleared, warns and exits 1. Set `FORGE_EVALUATION_GATE=0` to disable |
| `docs-drift-gate.sh` | `PreToolUse` | `Bash` | Before a `git commit` command | When the commit changes a skill's `SKILL.md` or a plugin's hooks, names the exact practical guide to reopen (`docs/skills/<plugin>/<skill>.md`, the plugin README) so the human-facing what/why/when/how stays true to the code. Warns (exit 1) by default; `FORGE_DOCS_GATE=strict` blocks (exit 2); `FORGE_DOCS_GATE=0` disables. Count drift is a trailing note, not the focus |
| `php-static-analysis.sh` | `PostToolUse` | `Write\|Edit` (`.php` files) | After editing a `.php` file | Runs PHPStan analysis on the changed file and emits a warning if issues are found |
| `js-static-analysis.sh` | `PostToolUse` | `Write\|Edit` (`.js/.ts/.tsx` files) | After editing a TypeScript or JavaScript file | Runs ESLint / TypeScript analysis and surfaces issues inline |
| `test-nudge.sh` | `PostToolUse` | `Edit\|Write` | After any file edit | Increments an edit counter; nudges to run tests every N edits to avoid accumulating untested changes |
| `test-nudge-reset.sh` | `PostToolUse` | `Bash` | After any Bash tool call | Resets the test-nudge counter when the command looks like a test run, so the nudge stays quiet during active test cycles |
| `filter-test-output.sh` | `PostToolUse` | `Bash` | After any Bash tool call | Compresses verbose test output so it doesn't flood the context window |
| `task-completion-gate.sh` | `TaskCompleted`¹ | (none) | When a task is marked complete | Checks the evaluation gate at task-completion boundaries; warns if verification was skipped |
| `route-failure.sh` | `PostToolUseFailure` | (none) | After any tool failure | Classifies the error into `compile-error\|test-fail\|type-error\|lint-warning` and nudges toward the corrective skill (arXiv:2605.18747 §5.2.2 feedback-type routing). Advisory; deduped per session by `(class, error-md5)` |

¹ `TaskCompleted` is an agent-teams event — only fires when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set. Without that env var the hook is inert.

## Agents

`adversarial-reviewer.md` — read-only critic forked into a subagent for assessments.

## How to use it

Run `/verify` at the end of any task to require evidence (test output, exit codes, diffs) before claiming done. After a generator or reviewer subagent stops, `auto-verify.sh` automatically reads the feature gate and surfaces a PASS/FAIL structured signal so the next subagent starts with explicit evidence status rather than an assertion.

For project code health: `/healthcheck` runs all configured pipelines in one command. For adversarial review of a specific change: `/challenge`. For any non-trivial self-evolution proposal: `/assess-proposal`.

## Disable

`/plugin disable evaluator@forge-studio`. You lose the verification gate — nothing else stops you from claiming a task done without proof. Static analysis hooks and the auto-verify nudge also stop firing.
