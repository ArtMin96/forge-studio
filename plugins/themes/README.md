# themes

Curated color themes for Claude Code. All themes are pure JSON — no hooks, no scripts, no overhead.

## Bundled themes

| Theme | Base | Vibe | Slug |
|-------|------|------|------|
| **Catppuccin Mocha** | dark | Pastel mauve / peach / teal. Soft, warm, low-contrast. | `custom:themes:catppuccin-mocha` |
| **Tokyo Night** | dark | Soft blues + violet on deep navy. Modern, balanced. | `custom:themes:tokyo-night` |
| **Nord** | dark | Frost cyan + aurora accents. Calm, cool, low-eye-strain. | `custom:themes:nord` |

## Switching themes

Two ways, both built into Claude Code:

1. `/theme` — interactive picker. Bundled themes appear under custom themes; arrow-keys to select, Enter to apply. Choice persists automatically.
2. `/config` → Theme tab — same picker, embedded in the settings UI.

Selection is stored as `custom:themes:<slug>` in your local Claude Code config and survives restarts. There is no `theme` field in `settings.json`; the picker writes to internal config.

## Customizing a bundled theme

Plugin-shipped themes are read-only. To tweak one:

1. Run `/theme`, highlight the theme you want to fork.
2. Press `Ctrl+E` — Claude Code copies the JSON to `~/.claude/themes/<slug>.json`.
3. Edit any `overrides` value in your editor. Claude Code watches the directory and hot-reloads — no restart.

The forked file takes precedence over the bundled one with the same slug.

## Adding a new theme to this plugin

1. Drop a new file in `plugins/themes/themes/<slug>.json`.
2. Required shape:
   ```json
   {
     "name": "Display Name",
     "base": "dark",
     "overrides": { "claude": "#...", "...": "#..." }
   }
   ```
3. `base` must be one of: `dark`, `light`, `dark-daltonized`, `light-daltonized`, `dark-ansi`, `light-ansi`. Tokens omitted from `overrides` fall through to the base preset.
4. Color values: `#rrggbb`, `#rgb`, `rgb(r,g,b)`, `ansi256(n)`, or `ansi:<name>` (e.g. `ansi:cyanBright`). Unknown tokens and bad colors are ignored — typos cannot break rendering.
5. Optional but recommended: include the eight `*_FOR_SUBAGENTS_ONLY` tokens so subagent transcripts sit inside your palette.

Full token reference: <https://code.claude.com/docs/en/terminal-config#create-a-custom-theme>

## Disabling

`/plugin disable themes@forge-studio` removes the entries from `/theme`. Your active selection falls back to the previous built-in.
