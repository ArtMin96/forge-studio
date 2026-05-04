---
name: verify-refs
description: Cross-check file paths, function names, and external references claimed in your prior turn against the actual repo. Catches fabricated references (hallucinated file paths, misspelled symbols, dead URLs) before they reach a commit message, PR body, or user-facing summary.
when_to_use: Reach for this after drafting any summary, PR description, commit message, or review response that names specific files/symbols/URLs, and before claiming a change touches X when you haven't verified X exists. Do NOT use for runtime verification (tests, lint) — that's `/verify`; verify-refs is purely a reference-existence sanity check.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Grep
  - Read
logical: every claimed file/symbol/URL classified YES / NO / SKIP with evidence; verdict line emitted
---

# Verify References

Research basis: Rao, Wong, Callison-Burch (2026) — "Detecting and Correcting Reference Hallucinations in Commercial LLMs" report 3–13% of citation URLs hallucinated by commercial LLMs and deep research agents. Code agents exhibit the same failure shape with file paths and symbol names — especially under context pressure.

This skill is **advisory**. Report findings; do not rewrite or delete the original claim automatically.

## 1. List Every Reference in Your Prior Turn

Extract from your most recent assistant response:

- **File paths** — anything matching `<segment>/<segment>.<ext>` or backticked paths.
- **Function / class / method names** — backticked identifiers that look like code symbols.
- **URLs** — `http(s)://…` links to external resources.
- **Package names** — npm/composer/pip/cargo package identifiers claimed to exist.
- **Environment variables / config keys** — anything presented as "the project uses `FOO_BAR`".

Write them into a table. One row per claim. Do not filter — check everything.

## 2. Verify Each Class

### File paths
```bash
test -e <path> && echo "EXISTS" || echo "MISSING"
```
If the path is relative, resolve it against the repo root.

### Symbols
```bash
git grep -n -- '<symbol>'
```
Expect at least one hit. Zero hits = fabricated or renamed.

### URLs
Do not fetch by default (slow, side-effecting). Flag URLs for the user unless they explicitly ask for a liveness check. If asked, use WebFetch.

### Package names
For the package manager in use (`composer show <pkg>`, `npm ls <pkg>`, etc.), check installed state; do not blindly query registries.

### Env vars / config keys
```bash
git grep -n -- '<KEY>'
```
Plus check `.claude/settings.json`, `composer.json`, `package.json` as appropriate.

## 3. Report

```markdown
| Claim                | Class  | Found? | Evidence                       |
|----------------------|--------|--------|--------------------------------|
| plugins/agents/...   | path   | YES    | test -e → exists               |
| FooServiceImpl       | symbol | NO     | git grep → 0 hits              |
| https://fake.example | url    | SKIP   | flagged — ask user to verify   |
```

Then emit a verdict line:

```text
VERIFIED-REFS: <N_found>/<N_total> ok. <N_missing> missing. <N_skipped> skipped.
```

## 4. On Missing References

For each missing reference, offer **one** of:

1. Correction — if you can find the real path/symbol via grep, propose the fix.
2. Retraction — if the claim was wrong, say so plainly in the next turn.
3. Investigation — if it's ambiguous, surface it for the user and pause.

Never silently rewrite the prior turn. The goal is faithful correction, not retroactive cover-up.

## 5. Skip Conditions

- Zero file paths / symbols / URLs in prior turn → skill returns `NO-REFS`. Silent success.
- Single trivial path that's in the current diff → skill can short-circuit after one grep. Don't bikeshed.

## 6. When to Run

- Before pasting a PR body or commit message.
- After a long summary of changes across multiple files.
- When the user asks "did you actually do X" — run this first, then answer.
- After context pressure warnings (Stage 3+) — reference hallucination risk climbs with fill.
