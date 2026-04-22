---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree.
when_to_use: When in plan mode, stress-testing a plan, or the user says "grill me".
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
