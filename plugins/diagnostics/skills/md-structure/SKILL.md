---
name: md-structure
description: Audit or scaffold a CLAUDE.md against the Karpathy 4-section structure (Think Before Coding · Simplicity First · Surgical Changes · Goal-Driven Execution). Companion to /lean-md — structure audit, not size trim.
when_to_use: Reach for this when authoring a fresh CLAUDE.md, when reviewing one against the four Karpathy sections, or when `/entropy-scan` calls in for a structure sub-check. Do NOT use for deleting or compressing lines — use `/lean-md` instead; this skill answers "is the architecture right?", not "is it too big?".
paths:
  - "**/CLAUDE.md"
disable-model-invocation: true
argument-hint: [path-to-claude-md]
allowed-tools:
  - Read
  - Write
  - Glob
logical: report shows PRESENT / WEAK / MISSING for each of the 4 Karpathy sections with line numbers
---

# /md-structure — 4-Section Karpathy Audit

Audits (or scaffolds) CLAUDE.md against the four sections Karpathy's failure-mode analysis maps to. `/lean-md` handles *how much*; this skill handles *how organized*. Run both.

## The Four Sections

1. **Think Before Coding** — surface assumptions; ask over guess; present alternatives when ambiguous.
2. **Simplicity First** — minimum code that solves the problem; no speculative features; no single-use abstractions.
3. **Surgical Changes** — touch only what the request requires; flag pre-existing issues without fixing them.
4. **Goal-Driven Execution** — define success criteria; loop until verified; format: `**N. [Step] → verify: [check]**`.

## Process

1. **Parse path** from `$ARGUMENTS`. Default `./CLAUDE.md`. If missing, report `CLAUDE.md not found at <path>` and offer to scaffold.

2. **Audit existing file.** For each of the four sections:
   - Does the section (or an equivalent heading) exist?
   - Is a concrete rule stated?
   - Is a concrete example or recipe given?
   Map heading aliases (e.g. "Think First" ≈ section 1; "Keep it simple" ≈ section 2; "Minimal changes" ≈ section 3; "Verify" ≈ section 4).

3. **Emit report:**
   ```
   CLAUDE.md STRUCTURE AUDIT
   =========================

   Section 1 — Think Before Coding     [PRESENT / MISSING / WEAK]
   Section 2 — Simplicity First        [PRESENT / MISSING / WEAK]
   Section 3 — Surgical Changes        [PRESENT / MISSING / WEAK]
   Section 4 — Goal-Driven Execution   [PRESENT / MISSING / WEAK]

   Notes:
     - <what's weak and why, file:line>
     - ...

   Next: run /lean-md to trim, or accept this structure as-is.
   ```

   `WEAK` = heading present but rule is vague (e.g. "be careful" without actionable guidance).

4. **Scaffold mode** (user asks to write a skeleton): emit a starter CLAUDE.md in the 4-section shape:
   ```markdown
   # <Project> — Contributor Notes

   ## Think Before Coding
   - Surface assumptions explicitly.
   - Ask over guess when requirements are ambiguous.

   ## Simplicity First
   - Minimum code that solves the problem. No speculative features.
   - No single-use abstractions; no config options without a real consumer.

   ## Surgical Changes
   - Touch only what the request requires.
   - Flag pre-existing issues as comments; do not fix in the same PR.

   ## Goal-Driven Execution
   **1. [Step] → verify: [check]**
   **2. [Step] → verify: [check]**
   ```

5. **Never overwrite** existing CLAUDE.md silently. Ask first.

## Execution Checklist

- [ ] Parse `$ARGUMENTS` (default `./CLAUDE.md`); offer scaffold if missing
- [ ] Audit each of the four sections (Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution) — check for heading or alias, concrete rule, and concrete example
- [ ] Emit the CLAUDE.md STRUCTURE AUDIT block with PRESENT / WEAK / MISSING per section and a Notes list citing `file:line`
- [ ] If scaffold mode is requested, emit the four-section starter document
- [ ] Never overwrite an existing CLAUDE.md silently — ask first

## Examples

### Example 1: existing CLAUDE.md, all four sections present

Input: `./CLAUDE.md` (210 lines) has top-level headings `## Think Before Coding`, `## Simplicity First`, `## Surgical Changes`, `## Goal-Driven Execution`, each with concrete rules.

Output:
```text
CLAUDE.md STRUCTURE AUDIT
=========================

Section 1 — Think Before Coding     PRESENT
Section 2 — Simplicity First        PRESENT
Section 3 — Surgical Changes        PRESENT
Section 4 — Goal-Driven Execution   PRESENT

Notes:
  - (none)

Next: run /lean-md to trim, or accept this structure as-is.
```

### Example 2: CLAUDE.md with weak section 3 and missing section 4

Input: `./CLAUDE.md` has `## Surgical Changes` heading but only the line "be careful when editing" (no actionable rule). No `## Goal-Driven Execution` heading or alias.

Output:
```text
CLAUDE.md STRUCTURE AUDIT
=========================

Section 1 — Think Before Coding     PRESENT
Section 2 — Simplicity First        PRESENT
Section 3 — Surgical Changes        WEAK
Section 4 — Goal-Driven Execution   MISSING

Notes:
  - Section 3 (CLAUDE.md:84) — heading present but only "be careful when editing"; needs an actionable rule (e.g. "touch only the files the request names").
  - Section 4 — no `Goal-Driven Execution` heading or alias (`Verify`, `Loop until verified`, etc.). Recommend scaffolding.

Next: scaffold section 4 with `/md-structure --scaffold`, then /lean-md.
```

## Integration

- **Partner skill:** `/lean-md` (context-engine) — trims; this skill structures. Run this first to set sections, then trim.
- **Runtime counterpart:** `/rules-audit` (behavioral-core) — audits compliance while the session runs; good structure (this skill) makes `/rules-audit` more effective.
- **Meta-check:** `/entropy-scan` (diagnostics) invokes this as a sub-check — weak CLAUDE.md surfaces as a drift signal.
- No ledger writes (read-only audit). Ledger writes happen only when a scaffold is applied, via follow-up `/commit-proposal` if the user chooses.

## Failure Modes

- CLAUDE.md empty → report all four sections MISSING; recommend scaffold.
- Exotic headings that don't map to the four sections → report PRESENT under "custom" with a note; user decides whether to refactor.
- Multiple CLAUDE.md paths (root + plugin-specific) → audit only the path passed in; do not globally glob.

## Do NOT

- Do not rewrite a section's content while auditing. Scaffolding is a separate explicit step.
- Do not add a 5th section on your own initiative — `/evolve` is the right path for structural changes to the audit itself.
