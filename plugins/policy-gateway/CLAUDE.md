# policy-gateway — local conventions

Read together with: ./README.md

## What this plugin owns

PreToolUse secrets scan, prompt-injection scan, and PostToolUse sensitive-ops audit. Same `permissionDecision: deny` JSON contract as `behavioral-core/block-destructive`. Rules live in `rules.d/` so SEPL can evolve them without touching shell code.

## Non-obvious invariants

- **deny() is the only way to block.** Three hooks (`scan-injection.sh:32-42`, `scan-secrets.sh:35-45`) duplicate the same `jq -n` template. If you change the contract shape, change all three together — Claude Code reads the JSON literally.
- **Always exit 0 on deny.** The `permissionDecision: deny` is delivered via the JSON body, not via a non-zero exit. Exit-non-zero would be treated as hook error and surface differently to the user.
- **Ledger writes go through `plugins/_lib/jsonl-append.sh`** — bare `>>` torn lines under concurrent denies. See append_ledger() in scan-injection.sh / scan-secrets.sh.
- **Rules files use line-oriented format.** `rules.d/secrets.txt` lines are `<regex>|<label>`; `rules.d/injection.txt` lines are bare regexes. Keep narrow — overbroad patterns generate noise that trains users to ignore the gate.

## Files to read first when changing this plugin

1. `hooks/scan-injection.sh` — the injection contract template
2. `rules.d/secrets.txt` and `rules.d/injection.txt` — the empirical rule corpus
3. `skills/policy-audit/SKILL.md` — the read side; understands the ledger entries this plugin writes

## Cross-plugin dependencies

- `behavioral-core/block-destructive.sh` — same `permissionDecision: deny` contract; if you change it here, consider updating there too
- `forge-meta/skills/change-manifest` — receives a manifest entry every time `policy-audit` flags drift in the rules corpus
