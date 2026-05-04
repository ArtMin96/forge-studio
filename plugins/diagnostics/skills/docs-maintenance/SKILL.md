---
name: docs-maintenance
description: Comprehensive documentation maintenance — audit freshness, validate links and images, enforce style consistency, optimize structure, and emit a quality report across all `*.md` / `*.mdx` files.
when_to_use: Reach for this before a release, after major content changes, on a weekly/monthly schedule, or when investigating doc drift, broken links, or stale content. Do NOT use for marketplace/harness drift between docs and code — that's `/entropy-scan` (drift) and `/validate-marketplace` (correctness); this skill covers project-level Markdown only.
argument-hint: "[--audit | --update | --validate | --optimize | --comprehensive]"
effort: xhigh
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
logical: report enumerates Critical / Warning / Info findings per file with line numbers
---

# /docs-maintenance — Documentation Maintenance & Quality Assurance

Run a systematic doc-quality pass across the project. Use `--audit` to scan only, `--update`/`--optimize` to apply fixes, `--validate` to verify links and references, and `--comprehensive` to do the whole sweep end-to-end.

## Current Documentation Health

Dynamic context — gathered fresh each run:

- Documentation files: !`find . -name "*.md" -o -name "*.mdx" | grep -v node_modules | grep -v .git | wc -l`
- Recently modified: !`find . -name "*.md" -not -path "./node_modules/*" -not -path "./.git/*" -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -5`
- External links: !`grep -rE "https?://" --include="*.md" --include="*.mdx" . 2>/dev/null | grep -v node_modules | wc -l`
- Image references: !`grep -rE "!\[.*\]\(" --include="*.md" --include="*.mdx" . 2>/dev/null | grep -v node_modules | wc -l`
- TODO/FIXME markers: !`grep -rE "TODO|FIXME|XXX" --include="*.md" --include="*.mdx" . 2>/dev/null | grep -v node_modules | wc -l`

## Mode Selection ($ARGUMENTS)

Interpret the first argument:

- `--audit` → run Sections 1–3 (read-only). Report findings; write nothing.
- `--validate` → run Section 2 only (links/images/references).
- `--optimize` → run Sections 3–4. May edit files to fix formatting, add TOC, fix alt text.
- `--update` → run Sections 4–5. Apply content + sync fixes; may create git commits.
- `--comprehensive` (default) → run all six sections; produce a full report + apply safe fixes.
- No argument or unknown mode → treat as `--audit`.

Always stop at the first section that produces critical findings unless the mode explicitly requires continuing.

## Framework

### 1. Content Quality Audit

- Enumerate all `.md` / `.mdx` files (exclude `node_modules`, `.git`, `vendor`, build output).
- Classify each: README, changelog, guide, API reference, architecture, notes.
- Detect staleness: last-modified date older than 90 days is `warn`, older than 180 is `stale`.
- Measure structure: heading depth, section count, word count, list density.
- Flag files with:
  - No H1, or multiple H1s
  - Missing common sections for their class (e.g., a README without "Install" or "Usage")
  - TODO / FIXME / XXX markers still present

### 2. Link & Reference Validation

- External links: HEAD request via `curl -sI --max-time 10`; retry once with GET if HEAD returns 405. Flag 4xx / 5xx / timeout.
- Internal links: resolve relative paths against the repo root; flag files that don't exist.
- Anchor links (`#section`): parse target file's headings; flag missing anchors.
- Image references: verify each `![alt](path)` target resolves; flag missing alt text (accessibility).
- Cross-references between docs: check that plugin/skill/agent names mentioned in docs still exist on disk.

### 3. Style & Consistency

- Markdown syntax valid (no unclosed code fences, no broken tables).
- Heading hierarchy (no jumps from H1 to H3 without H2).
- Code blocks specify language where non-trivial (`bash`, `python`, `json`, etc.).
- List-marker consistency per document (don't mix `-` and `*`).
- No trailing whitespace; single trailing newline per file.
- Descriptive link text (flag generic "click here", "read more").

### 4. Content Optimization (write-mode only)

- Generate a Table of Contents for any doc >200 lines that lacks one.
- Normalize frontmatter: ensure YAML parses, no unknown keys, consistent field order.
- Fix trivial formatting: trailing whitespace, inconsistent list markers, missing code-fence languages (only when unambiguous).
- Insert alt text placeholders for images that lack it (never overwrite existing alt text).
- Never rewrite prose content — style fixes only.

### 5. Synchronization (update-mode only)

- Check `git status` before any write.
- Stage only files touched by this run.
- Compose a commit message listing the fixes applied, grouped by category.
- Do NOT push. Do NOT create branches. Human reviews before push.
- On failure: `git stash` the partial changes, report what stashed, ask the user how to proceed.

### 6. Quality Report

Emit a final report in this shape:

```markdown
## Docs Maintenance Report — <timestamp>

Mode: <mode>
Files scanned: <N>

### Critical ({N})
- <file>:<line> — <issue> — Fix: <suggestion>

### Warning ({N})
- <file>:<line> — <issue>

### Info ({N})
- Recently modified: <list>
- Stale (>180d): <list>
- TODOs open: <count>

### Metrics
- External links: <total>, <N> broken, <N> warn
- Internal links: <total>, <N> broken
- Images: <total>, <N> missing alt, <N> missing file
- Total word count: <N>
- Avg readability (approx): <N>

### Actions Taken (write-modes only)
- Files modified: <list>
- Commit prepared: <yes/no>
- Stashed on failure: <list>

### Verdict
<PASS | NEEDS ATTENTION | FAIL>
<one-line remediation>
```

## Rules

- Default is read-only. Switch to write-mode only on explicit `--update` / `--optimize` / `--comprehensive`.
- Never rewrite prose. Formatting only.
- Never delete files or sections.
- Respect `.gitignore`; don't scan ignored paths.
- Cache link-check results within a single run; don't re-hit the same URL twice.
- Large doc sets (>500 files): process in batches of 100 and report incrementally.
- If `curl` is unavailable, skip external-link validation and report `SKIPPED` rather than failing.

## Integration

- Works alongside `/entropy-scan` (detects marketplace/harness drift) and `/validate-marketplace` (pre-commit correctness). This skill covers project docs; entropy-scan covers harness docs; validate-marketplace covers frontmatter/JSON.
- Safe to wire into a pre-release CI step using `--comprehensive` in audit-only mode.
