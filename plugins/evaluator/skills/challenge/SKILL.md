---
name: challenge
description: Use whenever the user wants a deep critique of a recently completed feature — runs Stage 1 self-review against the diff, then Stage 2 git-history verification (does the change actually pass historical evidence, not just current tests?). Forks to a general-purpose agent so the critique is independent of the original implementation context.
when_to_use: Reach for this after finishing complex features, security-sensitive code, or anything where "tests pass" isn't enough proof. Do NOT use for SEPL proposal verdicts (use `/assess-proposal`) or fast diff review (`/verify` is cheaper); challenge is the heavyweight option.
disable-model-invocation: true
effort: xhigh
context: fork
agent: general-purpose
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Challenge: Draft Verification Critique

Two-stage review. Stage 1 is your self-critique (the draft). Stage 2 retrieves historical evidence — both confirmers and challengers — to verify or refute the draft assessment.

## Stage 1: Self-Critique (Draft)

Review the code you just wrote. Answer honestly:

### 1.1 Could This Be Simpler?
- Is there a shorter, cleaner way to achieve the same result?
- Did you add any abstraction that's used only once?
- Are there any "just in case" additions that aren't needed?
- Count the lines changed. Could you achieve it in half?

### 1.2 What Breaks?
- What happens with null/empty/unexpected input?
- What happens under concurrent access?
- What if this runs twice? Is it idempotent?
- What's the failure mode — silent corruption or loud error?

### 1.3 What's the Weakest Part?
- Which section of the code are you least confident about?
- Where did you make assumptions without verifying?
- Is there any part where you're hoping it works rather than knowing it works?

### 1.4 Does This Match the Request?
- Re-read the original task. Did you do ONLY what was asked?
- Did you add anything beyond scope? Remove it.
- Did you change anything you weren't asked to change? Revert it.

### 1.5 Would a Staff Engineer Approve This?
- Is the code readable without comments?
- Does it follow existing patterns in the codebase?
- Would it survive a code review without changes?

## Stage 2: Historical Verification

For each file you changed, retrieve evidence from git history. This stage verifies your Stage 1 assessment against real project history.

### 2.1 Retrieve Confirmers (similar changes that succeeded)

For each modified file, run:
```bash
git log --oneline --diff-filter=M -10 -- <file>
```

Then for the most relevant commits, check what patterns they used:
```bash
git show <commit> -- <file>
```

Ask: Do your changes follow the patterns that have worked before in these files?

### 2.2 Retrieve Challengers (similar changes that caused problems)

Search for reverted or fix-up commits touching the same files:
```bash
git log --oneline --all --grep="revert\|fix\|hotfix\|rollback" -- <file>
```

Search for changes that were reverted within a week:
```bash
git log --oneline --diff-filter=M --since="3 months ago" -- <file> | head -20
```

Ask: Have similar changes to these files caused issues before? Are you repeating a known anti-pattern?

### 2.3 Pattern Check

If git history is available, also check:
- `git log --oneline --diff-filter=M --since="1 month" -- <file>` — is this a file hotspot? High churn = high risk
- Look for test files associated with modified files. Do tests exist? Are they passing?

If no git history is available (new repo, new files), skip Stage 2 and note it in the report.

## Output
```
CHALLENGE REPORT (Draft Verification)
======================================

Stage 1 — Self-Critique
  Simplification:  [Can/Cannot be simplified. If can: how]
  Risk:            [Highest risk area and why]
  Weakest Part:    [What and why]
  Scope Match:     [Yes/No. If no: what was added beyond scope]
  Staff Approval:  [Yes/Likely/No. If no: what needs to change]

Stage 2 — Historical Verification
  Confirmers:     [N past changes to same files followed similar patterns / no history]
  Challengers:    [N past issues found in same files / none found]
  Churn Risk:     [Low/Medium/High — based on recent change frequency]
  Verdict:        [CONFIRMED / CAUTION / REFUTED — does history support this change?]
```

Be ruthlessly honest. The point is to catch issues BEFORE the user does.
