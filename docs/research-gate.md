# Research Gate — Read-Before-Edit Enforcement

Mechanically blocks Edit/Write on files not Read in the current session. Based on data from [anthropics/claude-code#42796](https://github.com/anthropics/claude-code/issues/42796).

## The Problem

Issue #42796 analyzed 234,760 tool calls across 6,852 sessions and found:

| Period | Read:Edit Ratio | Edits Without Reading |
|--------|----------------|----------------------|
| Good (Jan 30 - Feb 12) | **6.6** | 6.2% |
| Degraded (Mar 8 - Mar 23) | **2.0** | **33.7%** |

One in three edits was made to files the model had never read. Text-based rules ("read before editing") degraded under context pressure. The community consensus:

> "Prompts are requests, hooks are guarantees."

## How It Works

Two hooks, no skills, zero per-message overhead.

### `track-file-reads.sh` (PostToolUse:Read)

Records every file Read in session state at `/tmp/claude-research-gate-${SESSION_ID}/`. Each file is hashed to a 16-char key.

### `require-read-before-edit.sh` (PreToolUse:Edit|Write)

Before any edit:

1. Extract `file_path` from tool input
2. **Write to new file** → allow (file doesn't exist yet)
3. Check if file was Read in this session
4. **Read found** → `exit 0` (allow)
5. **Not read** → `exit 2` (block) with message: `"BLOCKED: You must Read {file} before editing."`

Exit code 2 is non-bypassable — the tool call is mechanically prevented from executing.

## Rules

| Tool | Behavior |
|------|----------|
| **Edit** | Always blocked if file not Read in session |
| **Write** (existing file) | Blocked if file not Read in session |
| **Write** (new file) | Allowed — no prior Read needed |

## Configuration

Disable the gate entirely:

```json
{
  "env": {
    "FORGE_RESEARCH_GATE": "0"
  }
}
```

## Enforcement Layers

Research-gate fills the one mechanically enforceable gap in the harness:

| Layer | Mechanism | Compliance | Blocks? |
|-------|-----------|------------|---------|
| `rules.d/50-verify-before-done.txt` | Text injection every message | ~80-100% | No |
| `context-engine/track-edits.sh` | PostToolUse warning after 3 edits | ~80% | No |
| **`research-gate/require-read-before-edit.sh`** | **PreToolUse exit 2** | **100%** | **Yes** |

Text rules cover the broader "research first" behavior (reading related files, checking tests, grepping for usages). The hook covers the hard constraint: never edit a file you haven't read.

## Token Cost

- **Per Read call**: ~1ms to write a hash file (PostToolUse)
- **Per Edit/Write call**: ~1ms to check a hash file (PreToolUse)
- **Per message**: Zero — no UserPromptSubmit hook
- **Context overhead**: Zero until gate blocks; then one short message

## Background

See [anthropics/claude-code#42796](https://github.com/anthropics/claude-code/issues/42796) for the full analysis including weekly Read:Edit ratio decline, reasoning loop frequency, premature stopping patterns, and economic impact data.
