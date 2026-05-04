---
name: zoom-out
description: Use when the user is unfamiliar with a section of code, asks "what does this fit into", "where does this get called from", or wants a higher-level map before diving into a specific function — returns a one-screen map of relevant modules, callers, and the layer above the current file.
when_to_use: Reach for this before reading deep into unfamiliar code, when planning a refactor that may have non-obvious callers, or when onboarding to a new codebase. Do NOT use for narrow line-level questions — direct reading or grep is cheaper there.
disable-model-invocation: true
model: haiku
logical: high-level map returned showing call-graph entry points and main subsystems for the target
---

I don't know this area of code well. Go up a layer of abstraction. Give me a map of all the relevant modules and callers.
