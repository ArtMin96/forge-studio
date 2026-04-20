# RTK Optimizer — Auto-Bundled Token Killer

Wraps [rtk-ai/rtk](https://github.com/rtk-ai/rtk) as a forge-studio plugin. Installs the `rtk` binary on first session start and registers rtk's own PreToolUse hook so every `Bash` tool call is transparently rewritten (`git status` → `rtk git status`, `cargo test` → `rtk cargo test`, etc.), compressing command output before it reaches the LLM context.

Upstream claims 60–90% token reduction on shell-heavy commands. Verified locally: `rtk 0.37.2`, binary ~9.8 MB, one-time install completes in well under 45 s.

---

## Why this plugin exists

RTK is an external Rust CLI that solves a problem forge-studio already cares about (token spend on verbose tool output, see [token-optimization.md](token-optimization.md)) but from a different angle — *content-level* compression of the stdout itself, rather than *behavioral* nudges about when/what to read. The two are complementary:

| Approach | Where it acts | Plugin |
|---|---|---|
| Warn when output is large | Post-hoc advisory | `token-efficiency` |
| Filter passing test noise | PostToolUse transform | `evaluator` (backpressure hook) |
| Compress command output at source | Subprocess wrapper | **`rtk-optimizer`** |

Without this plugin the user would: (a) install rtk manually, (b) run `rtk init -g --auto-patch`, (c) remember to do the same on every new machine. This plugin collapses all of that to `/plugin install rtk-optimizer@forge-studio`.

---

## What gets installed, where

| Artifact | Path | Owner | Removed by plugin uninstall? |
|---|---|---|---|
| `rtk` binary | `~/.local/bin/rtk` | rtk's install script | No |
| PreToolUse hook | `~/.claude/settings.json` → `hooks.PreToolUse[].hooks[].command = "rtk hook claude"` | `rtk init -g --auto-patch` | **No** — run `rtk init -g --uninstall` to remove |
| `RTK.md` instructions | `~/.claude/RTK.md` + `@RTK.md` reference appended to `~/.claude/CLAUDE.md` | `rtk init` | No — delete manually |
| rtk state | `~/.local/share/rtk/` (tee logs, telemetry consent, our bootstrap marker) | rtk | No |
| Bootstrap marker | `~/.local/share/rtk/.forge-studio-initialized` | this plugin | No |

The asymmetry matters: **uninstalling `rtk-optimizer@forge-studio` does not undo the global mutations above.** The plugin is a convenience installer — it does not own the installed artifacts. Use `rtk init -g --uninstall` to remove the hook, then `rm ~/.local/bin/rtk ~/.claude/RTK.md` to remove the rest.

---

## Bootstrap flow

`plugins/rtk-optimizer/hooks/rtk-bootstrap.sh` runs on every `SessionStart` with a 45 s timeout. Logic:

1. `FORGE_RTK_DISABLED=1` → exit 0.
2. Per-session marker at `/tmp/forge-rtk-${CLAUDE_SESSION_ID}` → exit 0 if already touched.
3. Persistent marker at `~/.local/share/rtk/.forge-studio-initialized` **and** `command -v rtk` → exit 0 (fast path, ~30 ms).
4. If `rtk` is missing: `curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh`. Failures print a one-line warning and exit 0 (never blocks the session).
5. Run `rtk init -g --auto-patch`. The `--auto-patch` flag is mandatory — without it rtk prompts interactively and the non-TTY SessionStart context silently aborts the patch step (an earlier version of this plugin shipped without the flag and left `settings.json` unpatched; the commit that fixed it is [0357e12](https://github.com/ArtMin96/forge-studio/commit/0357e12)).
6. `mkdir -p ~/.local/share/rtk/ && touch ~/.local/share/rtk/.forge-studio-initialized` so the next session takes the fast path.

Every exit is `0`. A failed install degrades to "rtk not active" rather than "session broken."

---

## Verifying it works

After a fresh `/plugin install rtk-optimizer@forge-studio` and a new session:

```bash
# Binary installed
command -v rtk && rtk --version

# Hook registered globally
python3 -c "import json; import sys; \
  h = json.load(open('$HOME/.claude/settings.json')).get('hooks', {}); \
  sys.exit(0 if any(hh.get('command') == 'rtk hook claude' \
                    for g in h.get('PreToolUse', []) for hh in g.get('hooks', [])) else 1)" \
  && echo "hook OK"

# End-to-end rewrite
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | rtk hook claude
# Expect: {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#          "permissionDecisionReason":"RTK auto-rewrite",
#          "updatedInput":{"command":"rtk git status"}}}

# Savings report (after some activity)
rtk gain --graph
```

---

## Configuration

| Variable | Default | Effect |
|---|---|---|
| `FORGE_RTK_DISABLED` | unset | Set to `1` to make the bootstrap exit immediately. Won't uninstall anything already in place. |
| `RTK_TELEMETRY_DISABLED` | unset | Passed through to rtk itself (see [rtk telemetry docs](https://github.com/rtk-ai/rtk#telemetry-management)). |

Per-command tuning (exclude certain commands from rewrite, enable failure-tee, etc.) goes in `~/.config/rtk/config.toml` — see the rtk README. This plugin does not manage that file.

---

## Known limitations

- **Bash-only coverage.** rtk's hook matches `tool_name == "Bash"`. Claude Code's built-in `Read` / `Grep` / `Glob` bypass it. If you rely on `Read` for large files, pair this plugin with `token-efficiency` for large-output warnings.
- **`rtk init` mutates `~/.claude/CLAUDE.md`.** On first run rtk appends `@RTK.md` to the global CLAUDE.md. Benign but worth knowing before you blame the plugin for touching a file it doesn't own.
- **First-session network dependency.** Offline machines get a one-line warning and no rtk. Re-run the hook (start a session) when online, or install rtk manually and just touch the marker.
- **Supply chain.** First session pipes `curl | sh` from `rtk-ai/rtk` `master`. Installing this plugin is opting into that. Set `FORGE_RTK_DISABLED=1` before the first session if you want to vet the install script first, then unset it once you're satisfied.

---

## Uninstall

```bash
rtk init -g --uninstall                         # remove the hook from ~/.claude/settings.json
rm -f ~/.local/bin/rtk ~/.claude/RTK.md         # remove binary + instructions
rm -rf ~/.local/share/rtk                       # remove state (optional)
/plugin uninstall rtk-optimizer@forge-studio    # remove the bootstrap hook itself
```

Also remove the `@RTK.md` line from `~/.claude/CLAUDE.md` if present.
