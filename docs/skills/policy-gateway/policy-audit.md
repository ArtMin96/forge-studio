# Policy Audit

`/policy-audit` is a two-pass security checkup for the `policy-gateway` plugin. The first pass replays the lineage ledger — counting secret-detection blocks, injection-pattern blocks, and sensitive-operation audits by label over the last 30 days. The second pass scans the live working tree for the same secret patterns the real-time hooks use, reporting every match by file and line without printing the matched value. It belongs to the `policy-gateway` plugin, which enforces pre-tool secrets scanning, prompt-injection detection, and sensitive-operation auditing on every Claude Code session.

---

## Install

```bash
/plugin install policy-gateway@forge-studio
```

```text
/policy-audit
```

No arguments. The skill reads the ledger and scans the working tree automatically, then emits a `POLICY AUDIT` report combining both passes.

## Why you need it

The `policy-gateway` hooks block secrets and injection attempts at the moment they occur, but the ledger of those blocks is not summarized anywhere unless you look for it. Over time, a pattern can emerge — the same secret pattern triggered three times this month, the same file keeps appearing in sensitive-op audits — that is invisible if you look at individual hook outputs but obvious in an aggregated view. The ledger-replay pass makes that pattern visible.

The live-scan pass addresses a different gap: secrets that existed in the working tree before the plugin was installed, or that were committed in a pathway the hooks did not intercept (a bulk import, a file copied from outside the session). Hooks fire on tool calls; they cannot retroactively scan history. `/policy-audit` closes that gap on demand.

Critically, the live scan reports `file:line + label` only — never the matched value. Printing secrets to a log is itself a leak, and the skill's design reflects that constraint explicitly.

## When to use it

- On a periodic security checkup, particularly before a release or a dependency update that might expose previously-inert credentials.
- When `/rest-audit`'s Security axis flags an issue and you want a focused replay of what the policy-gateway has been blocking, rather than a full rest-audit.
- After onboarding a new contributor or integrating a new tool, to confirm no credentials landed in the working tree during the setup.

Do not use it for real-time blocking — that is the `scan-secrets.sh` and `scan-injection.sh` PreToolUse hooks, which fire automatically on every relevant tool call. `/policy-audit` is the after-the-fact audit and live-tree backstop, not a substitute for the hooks.

## Best practices

- **Triage live-scan findings before acting.** High-entropy strings — UUIDs, content hashes, fixture data — can trip the entropy heuristic and appear in the live-scan output as false positives. The skill flags them; you decide whether they are real secrets. Never auto-redact without confirming.
- **Rotate secrets found in the working tree, do not just delete them.** A credential that appears in `file:line` in the live scan was likely committed at some point. Deleting the file removes the exposure from the tree but does not invalidate the credential. Rotation is the required remediation.
- **Check for base64-encoded blobs if the live scan is clean but the risk is high.** The regex layer misses secrets hidden inside base64-encoded content. The skill documents this as a known limitation — a clean live-scan pass on a project that handles external credentials warrants a manual check of any encoded blobs.
- **Read the ledger counts before expanding rules.** If the ledger shows a pattern triggered many times with zero live-tree findings, the rule may be generating noise. The skill surfaces this; the fix is to narrow the rule in `rules.d/secrets.txt`, not to ignore the count.

## How it improves your workflow

`/policy-audit` turns the policy-gateway from a silent runtime guard into a visible, auditable security layer. The ledger replay shows what the hooks have been doing across the session history; the live scan confirms the current tree state. Together they answer the question "how secure is this working environment right now?" with evidence rather than assumption — making security checkups a routine, five-second operation rather than a manual grep exercise.

## Related

- [`../diagnostics/policies-list.md`](../diagnostics/policies-list.md) — lists the active policy rules loaded by the gateway hooks; use to review what patterns `/policy-audit` scans for
- [`../diagnostics/rest-audit.md`](../diagnostics/rest-audit.md) — full harness health audit; the Security axis invokes `/policy-audit` for a focused replay
- [`../forge-meta/change-manifest.md`](../forge-meta/change-manifest.md) — receives a manifest entry when `/policy-audit` flags rule-corpus drift via SEPL
- [Architecture](../../architecture.md) — behavioral steering and policy enforcement in the 8-component harness model
