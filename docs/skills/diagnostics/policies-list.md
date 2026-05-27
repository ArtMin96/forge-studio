# Policies List

`/policies-list` prints every policy enforcement point declared in `plugins/diagnostics/registry/policies.json`, grouped by verdict — deny, gate, anchor, nudge, and log. For each entry it shows the FS-id, the plugin that owns it, the hook event it fires on, the severity, and any bypass mechanism. It is a single discoverable index of what the harness blocks, anchors, nudges, or logs at runtime. It belongs to the `diagnostics` plugin, which provides health-checking and quality-gate skills across the harness.

---

## Install

```bash
/plugin install diagnostics@forge-studio
```

```text
/policies-list
```

No arguments. The skill reads `plugins/diagnostics/registry/policies.json` and renders the full index.

## Why you need it

Forge Studio's behavioral enforcement is distributed across multiple plugins — `behavioral-core`, `policy-gateway`, `research-gate`, and others all contribute hooks that block actions, inject steering text, or log events. Without a central index, understanding what the harness actually enforces requires reading every `hooks.json` and every hook script across the entire plugins tree. That kind of archaeology is slow, error-prone, and impossible to hand off to a new contributor.

`/policies-list` makes the enforcement surface legible in a single read. When you want to know why a particular action was blocked, which plugin controls it, and how to bypass it legitimately, this skill gives you the answer in seconds rather than minutes of grepping.

## When to use it

- When onboarding to Forge Studio, to understand the full set of enforcement points before writing code that might trigger them.
- Before disabling a plugin, to see exactly which policy enforcement disappears with it and make an informed decision about the risk.
- While authoring documentation that needs to cite a specific policy by its FS-id (FS01–FS42).
- When a hook unexpectedly blocks an action and you want to locate its policy entry and understand its bypass mechanism.

Do not use it to change a policy. The registry indexes existing enforcement scripts; the authoritative source is the implementation script itself and the `rules.d/` patterns that back it. Do not use it for behavioral compliance audits — use `/rules-audit` instead. `/policies-list` inventories enforcement points; it does not evaluate whether the session is complying with them.

## Best practices

- **Read the verdict semantics before interpreting results.** A `deny` verdict is unconditional (exit 2 / block); a `gate` verdict fires only when a conditional check trips; an `anchor` injects steering text but does not block. These distinctions matter when deciding whether to seek a bypass or live with the enforcement.
- **Cross-reference with `/entropy-scan` Check 13.** The policy registry can drift from the enforcement scripts on disk — an entry whose `implementation` path no longer exists is silently broken. Run `/entropy-scan` to surface that drift; `/policies-list` shows you what the registry claims, not what is necessarily on disk.
- **Use FS-ids in documentation, not script paths.** When writing docs, reference policies as `FS-id` (e.g., `FS07 — block-destructive`). FS-ids are stable; script paths can change with refactors.
- **Check bypass mechanisms before disabling a plugin.** Some enforcement points have documented bypass mechanisms (environment variables, allow-list files). If you need to exempt a specific workflow, use the bypass rather than removing the plugin entirely.

## How it improves your workflow

`/policies-list` turns a distributed enforcement system into a single-screen inventory. The verdict grouping makes it easy to see at a glance whether your harness is primarily blocking (deny/gate heavy), nudging (nudge/log heavy), or a mix. The FS-id scheme means you can reference a specific enforcement point in a design document or a postmortem and know that reference is stable regardless of how the underlying script is later reorganized.

## Related

- [`/entropy-scan`](entropy-scan.md) — Check 13 validates that the policy registry stays in sync with enforcement scripts on disk
- [`/rules-audit`](../behavioral-core/rules-audit.md) — audits runtime compliance with behavioral rules; policies-list shows the inventory, rules-audit evaluates adherence
- [`/rest-audit`](rest-audit.md) — the Security axis of the R.E.S.T. audit checks whether policy-gateway is armed; policies-list shows what it is armed with
- [Architecture](../../architecture.md) — where policy enforcement fits in the 8-component harness model
