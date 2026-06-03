# humanizer

On-demand prose editor. Hand it a draft and it rewrites the text to remove the patterns that make writing read as AI-generated, so it sounds like a person wrote it.

## What it does

Ships one explicit-invocation skill, `/humanizer`. It detects 30+ specific "AI tells" documented on [Wikipedia:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) — inflated significance, promotional filler, superficial `-ing` analyses, rule-of-three padding, synonym cycling, em-dash overuse, sycophantic openers, hedging — and rewrites each into a natural alternative while preserving the original meaning and length. The final rewrite contains no em or en dashes, the most reliable AI tell. A false-positive guard keeps it from flattening legitimate polished prose. Supply a writing sample and it mirrors your voice instead of producing neutral defaults.

It is pure prose work: no hooks, no file mutations, no session state. Nothing runs unless you invoke it.

## When to use

- You drafted a message, email, comment, or post and want it to sound human, not generated
- You are cleaning up text that reads stiff, promotional, or formulaic
- You want the output matched to your own voice via a writing sample

Skip it for compressing prose to save tokens — that is `/caveman` in the `caveman` plugin, which moves in the opposite direction. Do not point it at code, error strings, or tool output; it is a prose editor and can mistake structured text for writing to "fix."

## Skills

| Skill | Purpose |
|---|---|
| `/humanizer` | Rewrite a piece of text to remove AI-writing tells and sound human |

## Hooks

None. The skill is explicit-invocation only (`disable-model-invocation: true`).

## Disable

`/plugin disable humanizer@forge-studio`. The `/humanizer` skill becomes unavailable; nothing else changes.

## Credit

Ported from [blader/humanizer](https://github.com/blader/humanizer) (MIT, © 2025 Siqi Chen). The upstream license ships at `skills/humanizer/LICENSE`. Guide: [docs/skills/humanizer/humanizer.md](../../docs/skills/humanizer/humanizer.md).
