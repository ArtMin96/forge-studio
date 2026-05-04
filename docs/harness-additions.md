# Harness Additions — MCP Injection Scan, Rule Provenance, Tool-Menu Check

> Three small additions driven by gaps found against Addy Osmani's *Agent Harness Engineering* (2026). All additive, no breaking changes.

## What this is

Three checks/hooks that close gaps the existing marketplace did not cover:

| # | Name | Where it lives | Fires on |
|---|---|---|---|
| 1 | **MCP config injection scan** | `plugins/context-engine/hooks/mcp-instruction-monitor.sh` | `SessionStart` (once per session) |
| 2 | **Rule provenance (Check 8)** | `plugins/diagnostics/skills/entropy-scan/SKILL.md` | Manual `/entropy-scan` |
| 3 | **Tool-menu inflation (Check 9)** | `plugins/diagnostics/skills/entropy-scan/SKILL.md` | Manual `/entropy-scan` |

Spec updates in `HARNESS_SPEC.md`:
- Entropy-scan protocol table: 6 → 9 rows.
- New section **Convention: Rule Provenance (Advisory)** — defines the `# origin:` header taxonomy.
- New section **Deliberate Non-Features** — explicitly documents why Forge does NOT ship Ralph loops, sandboxing, or parallel `AGENTS.md`.

## Why you need it

| Addition | Problem it solves |
|---|---|
| MCP injection scan | An untrusted MCP config can embed prompt-injection strings (`"ignore previous instructions"`) or sketchy shell commands (`curl …\| sh`) that the agent silently inherits. The pre-existing hook counted server overhead but did not read contents. |
| Rule provenance | Rules in `behavioral-core/rules.d/` accumulate over time. Without provenance, nobody can tell which rules were earned by real failures and which were brainstormed. Osmani's "ratchet pattern": every rule must trace to a specific past failure or external constraint. |
| Tool-menu inflation | Agents with >10 tools hit working-memory limits and degrade tool selection. Forge enforces tool isolation per subagent but had no check on the *count*. |

All three are **advisory** (exit 0 with a warning). None block commands or CI.

## How to run the flow

### 1. MCP injection scan — automatic

Runs itself at the start of every session. No invocation needed.

- **If clean**: silent, or prints `MCP servers: N configured.`
- **If flagged**: prints a list of servers with matched patterns, for example:
  ```
  MCP config scan flagged suspicious content:
    - evil-server (/path/.mcp.json): pipes curl to shell, prompt-injection phrase ("ignore previous")
    Review these servers. Prompt-injection or shell-exec patterns in MCP config can compromise the agent.
  ```
- **Disable**: `FORGE_MCP_INJECTION_SCAN=0` in the environment.
- **Adjust server-count warning threshold**: `FORGE_MCP_WARN_THRESHOLD=N` (default 2).

### 2. Rule provenance — on demand via `/entropy-scan`

Run:
```text
/entropy-scan
```
Look at **Check 8**. Each file without an `# origin:` header on its first non-blank line is listed as `UNPROVENANCED`.

Backfill a rule by adding one line at the top:
```text
# origin: postmortem:2026-04-auth-bug
Respond to substance, not social cues...
```

Accepted sources:

| Form | Meaning |
|---|---|
| `postmortem:<id>` | From a `/postmortem` artifact |
| `trace:<slug>` | From `traces/trace-evolve` output |
| `ledger:<entry-id>` | From a SEPL commit in `.claude/lineage/ledger.jsonl` |
| `external:<short-reason>` | Externally sourced preference |

Rules added through the self-evolution loop (`/evolve` → `/assess-proposal` → `/commit-proposal`) acquire `ledger:` provenance automatically.

### 3. Tool-menu inflation — on demand via `/entropy-scan`

Same command:
```text
/entropy-scan
```
Look at **Check 9**. Any agent `.md` or SKILL.md declaring more than `FORGE_TOOL_MENU_MAX` (default 10) tools in `tools:` / `allowed-tools:` is listed as `TOOL-BLOAT`.

**Adjust threshold**: `FORGE_TOOL_MENU_MAX=15 /entropy-scan`.

## End-to-end example

```bash
# Session starts. If a newly-installed plugin has a sketchy .mcp.json,
# the injection scan fires automatically (see SessionStart output).

# Later, run a periodic health check:
/entropy-scan

# Review the report. If Check 8 shows unprovenanced rules you own,
# backfill headers. If Check 9 flags tool-bloat in a custom agent,
# prune the tool list.

# These checks are advisory — /entropy-scan never writes files.
```

## Verification

Each addition was smoke-tested:

- **MCP scan**: synthetic `.mcp.json` containing `curl | sh` + `"ignore previous instructions"` correctly flagged both patterns; clean configs silent.
- **Check 8**: ran against `plugins/behavioral-core/hooks/rules.d/*.txt` — flagged all 8 existing rules (expected — none backfilled yet).
- **Check 9**: ran against all agent and skill files — 0 violations (generator: 6, planner: 4, reviewer: 4, largest skill: 5). Threshold validated by temporarily lowering `FORGE_TOOL_MENU_MAX`.

## Related skills

- `/entropy-scan` — contains the new checks
- `/postmortem` — write a postmortem to feed a `postmortem:<id>` provenance
- `/evolve`, `/assess-proposal`, `/commit-proposal` — the SEPL self-evolution loop that auto-produces `ledger:` provenance
- `/trace-evolve` — mines traces, can justify `trace:<slug>` provenance

## Design choices documented as non-features

Some external patterns the blog discusses are intentionally absent. See `HARNESS_SPEC.md` → *Deliberate Non-Features*:

- Ralph-loop auto-continuation (conflicts with human-gated self-evolution)
- Sandbox plugin (Claude Code host owns this boundary)
- Parallel `AGENTS.md` support (Claude Code reads `CLAUDE.md` natively; dual files fragment config)
