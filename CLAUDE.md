# Forge Studio — Project Instructions

## What This Is

A marketplace of composable Claude Code plugins implementing harness principles: behavioral steering, context management, memory, evaluation, orchestration, multi-agent decomposition, execution traces. No build step — markdown, JSON, shell scripts.

It is used daily by many people, on many kinds of projects, by readers who did not write it. So every shipped file and every doc must be correct, plain enough for a newcomer, and consistent with the code.

## Before You Start — Check the Authoritative Specs

Everything here targets Claude Code's own primitives, and those primitives change. Before building or changing hooks, plugins, agents, or skills, read the current official docs — do not rely on memory of an older API. This is the same no-fabrication rule applied to the platform: verify the spec, then build against it.

- Hooks: <https://code.claude.com/docs/en/hooks>
- Hooks guide: <https://code.claude.com/docs/en/hooks-guide>
- Plugins: <https://code.claude.com/docs/en/plugins>
- Sub-agents: <https://code.claude.com/docs/en/sub-agents>
- Skills: <https://code.claude.com/docs/en/skills>

## Definition of Done — the docs are part of the change

The rule skipped most often: **when you change behavior, you update the human-facing guide that describes it, in the same change, and you make it true to the new behavior.** A change whose guide still describes the old behavior is not done — it is worse than undone, because the page now lies to the next reader.

"Docs" here does **not** mean the counts. Counts are the last and smallest thing. Docs means the practical guide a newcomer reads to learn what the marketplace has and how to use it:

- **`docs/skills/<plugin>/<skill>.md`** — the per-skill guide. Shape is fixed by `docs/skills/README.md`: *what the skill is · why you need it · when to use it (and when NOT) · best practices · how it improves your workflow*. Write it for someone with zero context.
- **`plugins/<plugin>/README.md`** — what the plugin owns, why it exists, when to reach for it, what each hook and skill does.
- **`README.md`, `docs/architecture.md`, `HARNESS_SPEC.md`** — only when the change crosses the marketplace-wide story (a new plugin, a new harness component, a new event).

For every name, path, flag, output, or behavior you changed, this is the procedure — not a suggestion:

1. **Find every doc that mentions it:** `grep -rn "<old-name-or-path>" docs/ README.md HARNESS_SPEC.md plugins/*/README.md`
2. **Reopen each hit and rewrite the prose to match the code as it is now.** Confirm each claim by reading the script or running it — describe what it *does*, never what it was *meant* to do. A sentence you cannot verify against the code does not belong in the guide.
3. **Re-read the whole guide as a stranger.** Could someone who has never seen this plugin learn what it is, why it exists, and when to use it from this page alone? If not, it is not done.
4. **Counts, last.** `bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh .` must equal the README header line, the `## Active Hooks` paragraph, and the changed plugin's table row (column order `| Plugin | Purpose | Hooks | Skills |`). Mechanical — do it, then forget it.

The commit-time `docs-drift-gate.sh` (evaluator) names the exact guide file to reopen when a `SKILL.md` or a plugin's hooks change. It enforces step 1, not steps 2–3 — a guide can be touched and still lie. `FORGE_DOCS_GATE=strict` makes it block the commit; do not set `FORGE_DOCS_GATE=0` to dodge it.

## No Assumption, No Fabrication

- **Verify before you write — code and prose both.** Grep or read every matcher, env var, path, count, and flag before stating it. Use the codegraph MCP tools first (their usage is auto-injected each session — faster than grep, with caller/callee context). One unverified claim discredits the whole change.
- **Describe reality, not intent.** A guide that says a hook "blocks the commit" when the hook only warns costs the next reader an hour. Read the exit code, then write the sentence.
- **Report faithfully.** Failing check → show the output. Skipped step → say so. Never round incomplete work up to "done".

## The Codebase Is Not A Changelog

Shipped files (`.sh`, `.md`, `.json`) carry no process metadata. Never write sprint/phase markers (`# Sprint 2`, `(Sprint 9)`), references to plans / PRs / research, changelog notes (`Previously X`, `Replaced in vN`, `Was /handoff, now /progress-log`), or dangling references to removed components.

Comments and docs explain **why** the code is what it is — hidden constraints, invariants, bug workarounds. Not when or why it changed; the plan file, PR, and git history carry that.

## File Conventions

### Plugin structure
```text
plugins/{name}/
├── README.md                       # what it owns · why · when · per-hook/skill table
├── hooks/{hooks.json, *.sh}        # *.sh chmod +x. Events: SessionStart, UserPromptSubmit,
│                                   #   PreToolUse, PostToolUse, PreCompact, PostCompact
└── skills/{skill-name}/
    ├── SKILL.md                    # YAML frontmatter + instructions (copy an existing one)
    ├── scripts/                    # ≥10-line helpers, argv-driven, chmod +x
    └── evals/evals.json            # per-skill regression cases (/run-evals validates)
```
Hook exit codes: `0` info · `1` warn · `2` block (PreToolUse, PreCompact). Every skill ships its guide at `docs/skills/<plugin>/<skill>.md`.

### SKILL.md authoring
Copy an existing `SKILL.md` for the full frontmatter shape (optional fields include `paths`, `disable-model-invocation`, `context: fork`, and the SSL overlay `scheduling` / `structural` / `logical`, audited by `/ssl-audit`). The rules that matter:

- `description` + `when_to_use` ≤ 1536 chars combined, written from the user's POV.
- `when_to_use` ends with one exclusion clause naming a concrete sibling: `Do NOT use for X — use /sibling instead`.
- No all-caps imperatives (`MUST` / `NEVER` / `ALWAYS`) in body prose — state the rule and its reason.
- ≥10-line helpers live in `scripts/`, called via `bash scripts/<name>.sh`.
- Workflows over 3 steps ship a `## Execution Checklist` of `- [ ]` boxes.
- Artifact-producing skills ship 2 literal `Input:` / `Output:` example pairs.
- `## Known Failure Modes` documents real past pain only — never invented.

### marketplace.json
Every plugin is registered; `plugin.json` `version` matches its marketplace entry:
```json
{ "name": "...", "description": "...", "version": "1.0.0",
  "source": "./plugins/...", "category": "...",
  "tags": ["...", "harness:component", "overhead:zero|minimal|moderate"] }
```

### Plan files (`.claude/plans/`, gitignored, per-session)
When a plan instructs a change to a count, path, or table cell:

- Reference live state, not a snapshot. `58 → 59 hooks` rots the moment another plan lands first; write `<H>` or "increment the current count by 1".
- Mandate a read-from-disk first (e.g. `grep -nE "\b[0-9]+ hooks?\b" README.md`).
- Name the table column explicitly so a column-order slip can't pass.

## Project Config
```text
No build step.
Validate JSON: python3 -c "import json; json.load(open('file.json'))"
Test a hook:   echo '{"tool_input":{...}}' | bash plugins/{name}/hooks/{script}.sh ; echo $?
Counts:        bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh .
```

## Code Navigation

This repo has a codegraph knowledge graph. Use the codegraph MCP tools before Grep / Glob / Read for exploring code, tracing call paths, and checking the blast radius of a change — their usage is auto-injected each session, so it is not repeated here.
