# Scope

`/scope` turns a vaguely-bounded task into a written contract before any code is touched. You give it a task description; it inspects the repo, drafts a short scope document — task statement, an explicit file allowlist, an out-of-scope list, testable done-when criteria, and a max-files budget — and writes it to `.claude/scopes/<task>.md`. From that point on the `scope-guard.sh` hook reads the file on every edit and **blocks any Write or Edit to a file not on the allowlist**. The scope is both a planning artifact and a live fence.

It belongs to the `behavioral-core` plugin, which steers behavior with always-on rules and guards. `/scope` is the proactive guard: it constrains where the assistant is allowed to work before work begins.

---

## Install

```bash
/plugin install behavioral-core@forge-studio
```

```text
/scope add OAuth login support to the API
```

The argument is the task description. The skill slugifies it into a filename and writes `.claude/scopes/add-oauth-login-support-to-the-api.md`.

## Why you need it

Scope creep is the most common way a good change goes bad: you ask for one fix, the assistant "helpfully" refactors three neighbouring files, and now the diff is unreviewable and the regression surface is wide. The behavioral rule `60-minimal-changes` discourages this, but a rule is advice — `/scope` is enforcement. Once the allowlist exists, an out-of-scope edit is *denied at the tool layer*, not just frowned upon. You get a reviewable, bounded change every time.

The scope document is also a grading rubric. Its done-when section gives `/verify` and `/rules-audit` something concrete to check against, instead of a fuzzy memory of what you originally wanted.

## When to use it

Reach for it at the **start** of a task that has room to sprawl:

- Tasks touching 3+ files, or with acceptance criteria you'd want to grade against later.
- Work in an area where scope creep has bitten before.
- Any time you want a hard guarantee that unrelated files stay untouched.

Do not use it for one-line edits, typo fixes, or running existing tooling — direct execution is faster and the fence adds nothing. When an approved plan already exists, use [`/contract`](../agents/contract.md) instead; it re-reads success criteria from that plan rather than authoring a fresh scope.

## Best practices

- **Confirm the scope before implementing.** The skill stops and asks "Does this scope look right?" — treat that as a real gate. Tightening the allowlist now is free; widening it after a blocked edit costs a round-trip.
- **Keep the allowlist tight.** A scope that lists half the repo enforces nothing. If you genuinely can't predict the files, the task isn't ready to scope — explore first, then scope.
- **Pair it with a budget.** `/scope` carries a max-files number; for a hard ceiling on conversation length too, add [`/timebox`](timebox.md).
- **Let it expire.** Scopes are per-task. When the task is done, the file in `.claude/scopes/` is stale — a new task gets a new scope.

## How it improves your workflow

`/scope` is the "steer ahead of time" half of behavioral-core's steer→block→audit loop. By converting an informal request into an allowlist that `scope-guard.sh` enforces, it makes the minimal-change principle mechanical instead of aspirational. The result is diffs that match the request, reviews that stay tractable, and a written done-when that downstream gates can actually check. It trades thirty seconds of up-front definition for the elimination of an entire class of "why did it touch that file?" surprises.

## Related

- [`/timebox`](timebox.md) — hard message-count ceiling; complements the file-count budget in a scope
- [`/safe-mode`](safe-mode.md) — the reactive lockdown, where `/scope` is the proactive fence
- [`/rules-audit`](rules-audit.md) — audits after the fact for scope-creep the fence didn't catch
- [`/contract`](../agents/contract.md) — use instead when an approved plan already defines the criteria
- [Architecture](../../architecture.md) — behavioral steering in the 8-component harness model
