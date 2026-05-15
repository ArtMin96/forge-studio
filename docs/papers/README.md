# Research Papers

Cited findings drive the marketplace's design. PDFs kept here for offline reference; arXiv IDs are the canonical citations.

## Cited

| arXiv ID | Short name | What it gives us | Used by |
|---|---|---|---|
| `2603.05344` | Terminal-Agents | Doom-loop detection (Algorithm 1, p.15-16); signal-architecture framing for budget triggers (p.25) | `diagnostics/hooks/doom-loop.sh`, `long-session/hooks/budget-trigger.sh` |
| `2603.28052` | Meta-Harness | Execution-trace ablation: full traces vs compressed summaries; environment-bootstrap pattern | `traces/` plugin, `context-engine/hooks/env-bootstrap.sh`, `docs/research.md`, `docs/traces.md` |
| `2604.17025` | CAAF | Verification mandate (p.39): post-subagent verify hooks must not be discretionary | `evaluator/hooks/auto-verify.sh`, `evaluator/README.md` |
| `2604.25850` | Agentic Harness Engineering (AHE) | Controllability invariant (p.5) — evolution agent must not disable its own oversight; paired predictions verified against outcomes | `forge-meta/POLICY.md`, `evaluator/skills/prediction-audit/SKILL.md`, `docs/self-evolution.md` |

## Unreferenced (kept for research reading)

These PDFs sit at this path but no plugin or doc currently cites them. Audit before pruning — a future skill may need the citation.

- `2603.03329v1.pdf`
- `2603.13966v2.pdf`
- `2603.25723v1.pdf`
- `2604.08224v1.pdf`
- `2605.12239v1.pdf`

## Cited but not stored locally

A handful of arXiv IDs appear in source/docs but the PDF is not under this directory. Pull on demand:

- `arXiv:2604.15034`
- `arXiv:2604.22748`
- `arXiv:2604.24026` — SSL overlay (skill scheduling/structural/logical fields)
- `arXiv:2605.08060` — chain-of-thought degradation under accumulated defection (cited in behavioral-core rule 65)
