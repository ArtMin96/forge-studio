---
name: grill-me
description: Use when the user says "grill me", "interview me", "stress-test this plan", or you're in plan mode and the design has branches with unresolved decisions — runs a structured interview, walking each branch of the decision tree, recommending an answer for every question, and refusing to move on until shared understanding is reached.
when_to_use: Reach for this before locking a non-trivial design, when requirements feel under-specified, or before handing a plan to `/dispatch`. Do NOT use to argue against a chosen direction — that's `/devils-advocate`; grill-me is about clarification, not opposition.
disable-model-invocation: true
model: haiku
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.
