# Humanizer

`/humanizer` rewrites text so it stops reading like AI wrote it. You hand it a draft (a message, an email, a comment, a doc section, an essay) and it produces a natural, human-sounding version that keeps the original meaning. It detects more than thirty specific tells documented on Wikipedia's "Signs of AI writing" page and replaces each one with a natural alternative. It is its own plugin, `humanizer`, with a single skill. It pairs naturally with the separate `caveman` plugin as an opposite prose tool: caveman strips prose down for token savings, humanizer rebuilds prose so it sounds like a person.

The skill is explicit-invocation only (`disable-model-invocation: true`). It does not fire on its own, so it never touches code, internal replies, or tool output. You run it on the exact text you want humanized.

---

## Install

```bash
/plugin install humanizer@forge-studio
```

```text
/humanizer <paste your text, or a file path>
```

It is the only skill in the `humanizer` plugin; installing the plugin gives you `/humanizer`.

## Why you need it

AI-generated prose has a recognizable texture: inflated significance ("marks a pivotal moment in the evolving landscape"), promotional filler ("nestled in the heart of"), rule-of-three padding, synonym cycling, em-dash overuse, sycophantic openers ("Great question!"), and hedged non-answers. Readers notice. When the text is something you send (an email, a Slack message, a PR description, a public post), that texture undercuts you.

Humanizer encodes the specific patterns that give AI writing away, with a before/after example for each, so the rewrite targets the real tells instead of vaguely "making it better." Its hardest rule is the em dash and en dash: the final rewrite contains none, because the em dash is one of the most reliable AI tells. It also preserves what makes writing human, with a false-positive guard so it does not flatten legitimate prose that happens to be polished.

## When to use it

- You drafted a message, email, or post and want it to sound like you wrote it, not a model.
- You are cleaning up text (yours or generated) that reads stiff, promotional, or formulaic.
- You want the output matched to your own voice: supply a writing sample and it mirrors your sentence length, vocabulary, and punctuation instead of producing neutral defaults.
- You are editing a doc or comment and want to strip "diff-anchored" narration ("this was added to replace...") so it describes the thing as it is.

Do not use it to compress prose for token savings. That is [`/caveman`](../caveman/caveman.md), which drops articles and filler to cut output tokens; humanizer moves in the opposite direction, toward full natural prose. Do not point it at code, error strings, or tool output. It is a prose editor, and it can mistake structured technical text for writing to "fix."

## Best practices

- **Give it a voice sample for anything that should sound like you.** Inline (`Humanize this. Here's a sample of my writing: [paste]`) or by file path. Without a sample it falls back to a natural, opinionated default voice, which is right for generic copy but not for "sound like me" messages.
- **Read the audit, not just the final text.** The skill delivers a draft, a short list of remaining tells ("what makes this still obviously AI generated"), and a final rewrite. The middle list teaches you which tells you personally lean on.
- **Trust the em-dash rule.** If the final rewrite still contains `—` or `–`, it is not finished. The skill scans for them before returning; if you spot one, ask it to finish the pass.
- **Match the register, do not over-humanize.** For encyclopedic, legal, or reference text, neutral and plain is the correct human voice. The skill knows this (it gates its "personality and soul" pass on the content type), but if you are editing technical docs, say so, so it does not inject opinions or first person.
- **Watch the caveman interaction.** If `/caveman` is active, your normal replies are compressed. Humanizer governs only the text you explicitly pass it, so the two do not fight, but do not expect caveman's terse style and a humanized full-prose draft in the same breath. Use humanizer on the specific artifact you are about to send.

## How it improves your workflow

Outward-facing text is where AI tells cost you the most, and they are easy to miss in your own draft. `/humanizer` gives you a repeatable editing pass that targets the exact patterns readers register as "this was written by a bot," with the option to match your own voice rather than a generic one. Instead of re-reading a draft and vaguely sensing it sounds off, you get a named list of what is off and a rewrite that fixes it. The result is text you can send without it announcing where it came from.

## Related

- [`caveman.md`](../caveman/caveman.md) — the opposite prose tool in the separate `caveman` plugin; compresses prose for token savings rather than humanizing it
- [Architecture](../../architecture.md) — behavioral steering in the harness model

## Credit

Ported from [blader/humanizer](https://github.com/blader/humanizer) (MIT, © 2025 Siqi Chen), itself based on [Wikipedia:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing). The upstream MIT license ships alongside the skill at `plugins/humanizer/skills/humanizer/LICENSE`.
