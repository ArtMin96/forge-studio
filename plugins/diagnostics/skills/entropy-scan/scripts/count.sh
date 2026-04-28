#!/usr/bin/env bash
# Reports plugin / skill / hook / agent / rule counts for drift comparison.
set -euo pipefail
cd "${1:-.}"

plugins=$(/usr/bin/find plugins -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
skills=$(/usr/bin/find plugins -name SKILL.md 2>/dev/null | wc -l)
agents=$(/usr/bin/find plugins -mindepth 3 -maxdepth 3 -type f -name '*.md' -path 'plugins/*/agents/*.md' 2>/dev/null | wc -l)
rules=$(/usr/bin/find plugins/behavioral-core/hooks/rules.d -mindepth 1 -maxdepth 1 -type f -name '*.txt' 2>/dev/null | wc -l)

hooks=$(python3 - <<'PY'
import json, glob
total = 0
for path in glob.glob('plugins/*/hooks/hooks.json'):
    with open(path) as f:
        data = json.load(f)
    for matchers in (data.get('hooks') or {}).values():
        if not isinstance(matchers, list): continue
        for entry in matchers:
            total += len(entry.get('hooks', []))
print(total)
PY
)

printf '%d plugins. %d skills. %d hooks. %d agents. %d behavioral rules.\n' \
    "$plugins" "$skills" "$hooks" "$agents" "$rules"
