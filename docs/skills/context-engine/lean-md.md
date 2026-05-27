# Lean MD

`/lean-md` trims a CLAUDE.md file down to only the directives that materially change Claude's observable behavior, applying the principle that every line must justify its existence. It reads the file, annotates each line as `[KEEP]`, `[REMOVE]`, or `[→ HOOK]`, presents a side-by-side view of the annotated original and the trimmed version, and asks before overwriting. It belongs to the `context-engine` plugin, which provides context measurement, pressure management, and belief-state safety for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install context-engine@forge-studio
```

```text
/lean-md                          # trims ./CLAUDE.md (default)
/lean-md ~/.claude/CLAUDE.md      # trims the global config
/lean-md path/to/CLAUDE.md        # trims any CLAUDE.md by path
```

The optional argument is the path to the CLAUDE.md file to process. When omitted, the skill defaults to `./CLAUDE.md` in the current project root.

## Why you need it

CLAUDE.md files accumulate. A rule gets added for a problem, then a clarification, then a related note. Six months later the file is 200 lines long and compliance has quietly dropped — not because Claude ignores rules, but because the model's attention is finite and a very long instruction file effectively buries the rules that matter most.

The research baseline for this skill comes from Boris Cherny's (Claude Code creator) workflow: a focused ~100-line CLAUDE.md consistently outperforms a 500-line one. The reason is not that 500 lines is hard to read — it is that many of those lines restate Claude's defaults. Claude already reads files before editing. It already uses git. It already follows language conventions. Every line that restates a default is a line that crowds out a rule Claude actually needs to be told.

`/lean-md` makes the audit mechanical: it checks each line against Claude's defaults, flags redundancy, and identifies rules that belong in a hook rather than a prose instruction.

## When to use it

Reach for `/lean-md` when a CLAUDE.md file has grown past its useful size or when rule compliance has noticeably dropped:

- When the file exceeds 100 lines and you want to apply the every-line-must-earn-its-place test.
- After [`/audit-context`](audit-context.md) identifies CLAUDE.md as the top overhead offender.
- Before sharing a project's CLAUDE.md as a template, to make sure it contains only intentional guidance.
- After a long project phase where many ad-hoc rules were added and never reviewed.

Do not use it for section-level reorganization — moving headings around, reordering sections, or restructuring the document. That is `/md-structure`. `/lean-md` cuts content; it does not rearrange it.

## Best practices

- **Save a backup before overwriting.** The skill suggests saving the original as `CLAUDE.md.backup` before writing the trimmed version. Take that offer. A trim that turns out to have cut too aggressively is easy to recover from with a backup; without one it requires reconstructing from git history.
- **Be aggressive with the 30-line test.** If the trimmed version is still over 100 lines, the skill instructs you to be more aggressive. Most files have more redundancy with Claude's defaults than they appear to — re-evaluate each kept line against the question "would Claude make a mistake if this line were missing?"
- **Move `always` and `never` rules to hooks.** Rules phrased as "always run the linter" or "never force push" belong in PostToolUse and PreToolUse hooks respectively, where they are enforced mechanically rather than advisory. The skill flags these; use the hook infrastructure in any Forge Studio plugin as the target.
- **Apply primacy/recency placement to what remains.** After trimming, the most-frequently-violated rules belong at the top and bottom of the file (first five lines, last five lines). The middle is where attention drops; reserve it for less critical guidance.

## How it improves your workflow

Every line you remove from CLAUDE.md returns a token to the working budget of every future session in that project. A file that goes from 200 lines to 80 lines is not just tidier — it materially increases the context available for actual work, and it increases the probability that the rules that remain are actually followed. `/lean-md` makes that return concrete by showing you the before-and-after counts and the list of removed sections. Paired with [`/audit-context`](audit-context.md) for identification and [`/token-pipeline`](token-pipeline.md) for ongoing monitoring, it is the primary tool for reducing the largest single source of fixed overhead in most projects.

## Related

- [`/audit-context`](audit-context.md) — identifies CLAUDE.md as an overhead source; run first to confirm the trim is warranted
- [`/token-pipeline`](token-pipeline.md) — in-flight pressure relief that may recommend `/lean-md` as a corrective action
- [`../token-efficiency/token-audit.md`](../token-efficiency/token-audit.md) — after-the-fact session waste analysis; useful for validating that the trim reduced overhead as expected
- [Architecture](../../architecture.md) — where context management fits in the 8-component harness model
