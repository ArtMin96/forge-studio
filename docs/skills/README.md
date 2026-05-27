# Skill Guides

End-user guides for Forge Studio's skills, grouped by plugin. Each guide follows the same shape: what the skill is, why you need it, when to use it (and when not), best practices, and how it improves your Claude Code workflow. Skills that chain into other skills or agents cross-link to them.

These are usage guides, not reference. For the mechanical contract of a skill, read its `SKILL.md`; for architectural framing, see [architecture.md](../architecture.md).

## behavioral-core — steer, bound, and audit agent behavior

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/rules-audit` | [rules-audit.md](behavioral-core/rules-audit.md) | After-the-fact scan of the session for behavioral-rule drift |
| `/scope` | [scope.md](behavioral-core/scope.md) | Writes a file-allowlist scope that `scope-guard.sh` enforces on every edit |
| `/timebox` | [timebox.md](behavioral-core/timebox.md) | Hard message-count ceiling for the current task |
| `/safe-mode` | [safe-mode.md](behavioral-core/safe-mode.md) | Toggles the destructive-edit lockdown; auto-triggers after repeated failures |

## agents — multi-agent orchestration

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/contract` | [contract.md](agents/contract.md) | Re-reads plan success criteria from disk before implementation begins |
| `/dispatch` | [dispatch.md](agents/dispatch.md) | Decides solo vs. pipeline vs. fan-out for a multi-step task |
| `/fan-out` | [fan-out.md](agents/fan-out.md) | Runs the same operation across many independent files in parallel |
| `/lean-agents` | [lean-agents.md](agents/lean-agents.md) | Cuts per-dispatch token cost in multi-agent work |
| `/worktree-team` | [worktree-team.md](agents/worktree-team.md) | Isolates concurrent work streams in separate git worktrees |

## evaluator — verification, critique, and quality gates

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/verify` | [verify.md](evaluator/verify.md) | Evidence gate: runs the listed checks before a task is marked done |
| `/challenge` | [challenge.md](evaluator/challenge.md) | Deep fork-based critique of a completed feature |
| `/devils-advocate` | [devils-advocate.md](evaluator/devils-advocate.md) | Argues the opposing case against a plan or decision |
| `/grill-me` | [grill-me.md](evaluator/grill-me.md) | Stress-tests a plan by interrogating its weak points |
| `/healthcheck` | [healthcheck.md](evaluator/healthcheck.md) | One-command quality snapshot for PHP and/or JS/TS projects |
| `/gate-report` | [gate-report.md](evaluator/gate-report.md) | Consolidated view of every quality warning raised this session |
| `/postmortem` | [postmortem.md](evaluator/postmortem.md) | Converts a resolved failure into a captured lesson |
| `/assess-proposal` | [assess-proposal.md](evaluator/assess-proposal.md) | Adversarial review of a self-evolution proposal |
| `/prediction-audit` | [prediction-audit.md](evaluator/prediction-audit.md) | Scores proposal predictions against observed outcomes |
| `/verify-refs` | [verify-refs.md](evaluator/verify-refs.md) | Cross-checks claimed paths/functions/references against reality |
| `/run-evals` | [run-evals.md](evaluator/run-evals.md) | Validates per-skill `evals.json` fixtures for conformance |
| `/run-evals-bench` | [run-evals-bench.md](evaluator/run-evals-bench.md) | With-skill vs. without-skill comparative benchmarks |
| `/optimize-description` | [optimize-description.md](evaluator/optimize-description.md) | Tunes a skill's description for better trigger accuracy |
| `/score-rubric` | [score-rubric.md](evaluator/score-rubric.md) | Aggregates weighted criterion scores into one rubric result |

## long-session — coherence across sessions and compactions

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/progress-log` | [progress-log.md](long-session/progress-log.md) | Appends session outcomes to the durable `claude-progress.txt` |
| `/session-resume` | [session-resume.md](long-session/session-resume.md) | Rebuilds working context from the durable artifacts |
| `/feature-list` | [feature-list.md](long-session/feature-list.md) | Expands a plan's contract into machine-readable `features.json` |
| `/forward-briefing` | [forward-briefing.md](long-session/forward-briefing.md) | Forward-framed view of recent progress entries |
| `/init-sh` | [init-sh.md](long-session/init-sh.md) | Generates an `init.sh` that bootstraps the dev environment |

## workflow — session orchestration and pipelines

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/orchestrate` | [orchestrate.md](workflow/orchestrate.md) | Runs the planner→generator→reviewer pipeline per task |
| `/living-spec` | [living-spec.md](workflow/living-spec.md) | Maintains a shared `spec.md` source of truth for subagents |
| `/convergence-check` | [convergence-check.md](workflow/convergence-check.md) | Evaluates a plan's convergence criterion as a shell command |
| `/reflect` | [reflect.md](workflow/reflect.md) | Captures a session's lessons into memory |
| `/rollback` | [rollback.md](workflow/rollback.md) | Reverts a problematic commit within the SEPL lineage |
| `/tdd-loop` | [tdd-loop.md](workflow/tdd-loop.md) | Enforces red→green test-first development across fresh-context phases |
| `/status` | [status.md](workflow/status.md) | Reports where the current session stands |
| `/zoom-out` | [zoom-out.md](workflow/zoom-out.md) | Steps back to the big picture when lost in detail |
| `/evolve` | [evolve.md](workflow/evolve.md) | Drives a self-evolution proposal cycle |
| `/commit-proposal` | [commit-proposal.md](workflow/commit-proposal.md) | Turns an accepted proposal into a commit |
| `/router-tune` | [router-tune.md](workflow/router-tune.md) | Tunes the prompt-router classification thresholds |

## forge-meta — evolution ledger and skill self-improvement

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/change-manifest` | [change-manifest.md](forge-meta/change-manifest.md) | Writes a structured entry to the evolution ledger |
| `/evolution-history` | [evolution-history.md](forge-meta/evolution-history.md) | Renders the ledger as a chronological timeline |
| `/manifest-analyze` | [manifest-analyze.md](forge-meta/manifest-analyze.md) | Aggregate report over the change manifest |
| `/session-digest` | [session-digest.md](forge-meta/session-digest.md) | Compact rollup of a session's evolution artifacts |
| `/harness-metrics` | [harness-metrics.md](forge-meta/harness-metrics.md) | Scores the seven harness quality dimensions |
| `/auto-tune-skill` | [auto-tune-skill.md](forge-meta/auto-tune-skill.md) | Proposes a Pareto-best rewrite of a skill body |
| `/skill-staleness-audit` | [skill-staleness-audit.md](forge-meta/skill-staleness-audit.md) | Flags skills whose docs have drifted from behavior |
| `/paper-research` | [paper-research.md](forge-meta/paper-research.md) | Grounds a paper's claims in the existing plugin surface |

## diagnostics — drift, correctness, and health audits

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/entropy-scan` | [entropy-scan.md](diagnostics/entropy-scan.md) | Detects drift between docs and code counts |
| `/validate-marketplace` | [validate-marketplace.md](diagnostics/validate-marketplace.md) | Checks marketplace.json correctness |
| `/docs-maintenance` | [docs-maintenance.md](diagnostics/docs-maintenance.md) | Audits project Markdown for freshness and links |
| `/md-structure` | [md-structure.md](diagnostics/md-structure.md) | Reports Markdown structural issues |
| `/rest-audit` | [rest-audit.md](diagnostics/rest-audit.md) | Scores reliability/evidence/scope/trace axes |
| `/ssl-audit` | [ssl-audit.md](diagnostics/ssl-audit.md) | Audits skill SSL-overlay frontmatter |
| `/policies-list` | [policies-list.md](diagnostics/policies-list.md) | Lists active policies and guards |
| `/startup-profile` | [startup-profile.md](diagnostics/startup-profile.md) | Profiles SessionStart hook cost |

## traces — execution-trace collection and analysis

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/trace-compile` | [trace-compile.md](traces/trace-compile.md) | Compiles raw events into a structured trace |
| `/trace-review` | [trace-review.md](traces/trace-review.md) | Reviews a compiled trace for problems |
| `/trace-stats` | [trace-stats.md](traces/trace-stats.md) | Summarizes trace metrics |
| `/trace-evolve` | [trace-evolve.md](traces/trace-evolve.md) | Turns trace findings into harness changes |
| `/trace-clarification` | [trace-clarification.md](traces/trace-clarification.md) | Captures clarification turns in a trace |
| `/failure-attribute` | [failure-attribute.md](traces/failure-attribute.md) | Attributes a failure to its root cause |
| `/reasoning-tilt` | [reasoning-tilt.md](traces/reasoning-tilt.md) | Detects reasoning bias across a session |

## context-engine — context budget and belief integrity

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/checkpoint` | [checkpoint.md](context-engine/checkpoint.md) | Snapshots working context for safe restore |
| `/audit-context` | [audit-context.md](context-engine/audit-context.md) | Reports where context tokens are going |
| `/token-pipeline` | [token-pipeline.md](context-engine/token-pipeline.md) | Optimizes the token pipeline for a session |
| `/lean-md` | [lean-md.md](context-engine/lean-md.md) | Trims Markdown for token efficiency |
| `/belief-audit` | [belief-audit.md](context-engine/belief-audit.md) | Detects when belief state drifts from disk |
| `/context-tricks` | [context-tricks.md](context-engine/context-tricks.md) | Reference of context-management techniques |

## memory — durable facts across sessions

| Skill | Guide | What it does |
|-------|-------|--------------|
| `/remember` | [remember.md](memory/remember.md) | Writes a durable fact to file-based memory |
| `/recall` | [recall.md](memory/recall.md) | Retrieves relevant stored memories |
| `/memory-index` | [memory-index.md](memory/memory-index.md) | Maintains the memory index |
| `/lineage-audit` | [lineage-audit.md](memory/lineage-audit.md) | Audits the SEPL ledger lineage |

## Smaller plugins

| Skill | Guide | Plugin — what it does |
|-------|-------|--------------|
| `/parallel-power` | [parallel-power.md](reference/parallel-power.md) | reference — patterns for parallel subagent work |
| `/ultrathink` | [ultrathink.md](reference/ultrathink.md) | reference — extended-thinking trigger |
| `/unix-pipe` | [unix-pipe.md](reference/unix-pipe.md) | reference — composing skills like Unix pipes |
| `/federated-fan-out` | [federated-fan-out.md](cross-repo/federated-fan-out.md) | cross-repo — fan-out across multiple repositories |
| `/aggregate-results` | [aggregate-results.md](cross-repo/aggregate-results.md) | cross-repo — combines per-repo results |
| `/sync-discovery` | [sync-discovery.md](cross-repo/sync-discovery.md) | cross-repo — discovers repos to operate on |
| `/token-audit` | [token-audit.md](token-efficiency/token-audit.md) | token-efficiency — runtime token-usage audit |
| `/policy-audit` | [policy-audit.md](policy-gateway/policy-audit.md) | policy-gateway — scans for credential/policy exposure |
| `/impact-trace` | [impact-trace.md](code-graph/impact-trace.md) | code-graph — blast-radius trace via the knowledge graph |
| `/caveman` | [caveman.md](caveman/caveman.md) | caveman — terse output-style mode |
