# Forge Studio — Project Instructions

## What This Is

A marketplace of composable Claude Code plugins implementing harness principles: behavioral steering, context management, memory, evaluation, orchestration, multi-agent decomposition, and execution traces.

## Completeness Requirements

Every change must be complete. Before calling work done:

1. **Follow references** — If you add/modify a plugin, check every file that references it (README.md, docs/architecture.md, marketplace.json, other plugins that interact with it)
2. **Update docs** — New plugin? Update README.md (install command, plugin reference section, active hooks table, architecture diagram). Modified hook? Update the Active Hooks table. New skill? Add to the plugin's reference table.
3. **Update architecture.md** — If the change affects harness components, the 7-component table, the three-layer diagram, or any architectural pattern
4. **Update marketplace.json** — Every plugin must be registered in `.claude-plugin/marketplace.json`
5. **Verify JSON** — After editing any JSON file, validate it parses: `python3 -c "import json; json.load(open('path'))"`
6. **Test hooks** — Run new/modified shell scripts with `bash path/to/script.sh` and verify exit code and output

## File Conventions

### Plugin Structure
```
plugins/{name}/
├── hooks/
│   ├── hooks.json       # Event registrations
│   └── *.sh             # Hook scripts (chmod +x)
└── skills/
    └── {skill-name}/
        └── SKILL.md     # YAML frontmatter + instructions
```

### SKILL.md Frontmatter
```yaml
---
name: skill-name
description: One-line description
argument-hint: <arg1> [arg2]           # optional
disable-model-invocation: true         # optional, zero-cost until invoked
context: fork                          # optional, runs in isolated subagent
allowed-tools:                         # optional, capability isolation
  - Read
  - Bash
---
```

### hooks.json Events
`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`

Hook exit codes: `0` = info, `1` = warning, `2` = block action (PreToolUse only)

### marketplace.json Entry
```json
{
  "name": "plugin-name",
  "description": "What it does",
  "version": "1.0.0",
  "source": "./plugins/plugin-name",
  "category": "category-name",
  "tags": ["tag1", "harness:component", "overhead:zero|minimal|moderate"]
}
```

## Documentation Checklist (for every plugin change)

- [ ] `README.md` — Install command, plugin reference table, active hooks table, architecture diagram counts
- [ ] `docs/architecture.md` — If new harness component or pattern
- [ ] `.claude-plugin/marketplace.json` — Plugin registered
- [ ] Hook scripts are executable (`chmod +x`)
- [ ] JSON files parse cleanly

## Project Config

```
No build step — this is a collection of markdown, JSON, and shell scripts.
Validate JSON: python3 -c "import json; json.load(open('file.json'))"
Test hooks: bash plugins/{name}/hooks/{script}.sh
```
