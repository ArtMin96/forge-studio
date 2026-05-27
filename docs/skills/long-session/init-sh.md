# Init Sh

`/init-sh` generates an executable `init.sh` at the repo root that bootstraps the development environment — installing dependencies, copying the env file, noting migrations, and printing the dev-server and test commands — so any fresh session or new contributor can recreate the full working state with one command. It belongs to the `long-session` plugin, which pairs `init.sh` with `claude-progress.txt` as the two-command catch-up pattern for agents that start without context.

---

## Install

```bash
/plugin install long-session@forge-studio
```

```text
/init-sh
```

No arguments. The skill detects the repo's stack by reading the files present and writes a tailored `init.sh` to the repo root.

## Why you need it

Every long-running project develops an unwritten sequence of commands that makes the dev environment go: install the right tool version, copy the env file, run migrations, start the service in the right order. As a project evolves that sequence drifts and developers carry it in their heads. For a Claude Code agent starting a fresh session — or for a team member who hasn't touched the repo in a month — there is no reliable way to reconstruct it without exploring config files and often getting partway through before hitting a missing step.

`/init-sh` does the exploration once, writes it down as an executable and idempotent script, and commits it to the repo. Subsequent sessions skip the re-discovery. The script is safe to re-run because every install step is gated on whether the target already exists, so running it against a fully set-up environment is a no-op.

## When to use it

- At the start of a new project, before any long-session work has been logged.
- After major tooling changes — a new package manager, a new build step, a switched test runner — where the existing `init.sh` no longer reflects how to set up the environment.
- When a fresh session needs a one-command path to recreate state and no `init.sh` exists yet.

Do not use it for resuming an existing session — use `/session-resume` instead. `init-sh` produces the bootstrap script; `/session-resume` reads it and reminds you to run it when it finds one at the repo root.

## Best practices

- **Review the generated script before committing.** The skill infers commands from config files and applies reasonable defaults, but it cannot know about env-specific secrets, optional feature flags, or non-standard build steps. Read the output and add any project-specific steps it missed before committing.
- **Commit it alongside the lockfile.** `init.sh` is most useful when it is in version control and stays in sync with `package-lock.json`, `composer.lock`, or whatever lockfile your stack uses. Treat a lockfile change as a trigger to re-run `/init-sh` or update the script manually.
- **Keep it idempotent.** The skill writes every install step with guards (`[ ! -d node_modules ]`, etc.), and you should maintain that discipline if you edit the script by hand. An init script that breaks on a partially-set-up environment is worse than no script.
- **Pair it with `/progress-log`.** `init.sh` recreates the environment; `claude-progress.txt` recreates the context. Together they are Anthropic's recommended two-command pattern for long-running agents: `bash init.sh` then read the progress tail.

## How it improves your workflow

The setup cost for a fresh agent context is normally measured in turns of exploration — reading config files, guessing the right install command, discovering that migrations need to run before the server starts. `/init-sh` amortizes that cost to a single authoring session. After the script exists, every subsequent session — yours, a subagent's, a new contributor's — starts from a known-good environment in one command. `surface-progress.sh` detects the file at SessionStart and includes a reminder to run it, so the hint surfaces automatically without any manual coordination.

## Related

- [`/session-resume`](session-resume.md) — reads `init.sh` and reminds you to run it if the dev env isn't up
- [`/progress-log`](progress-log.md) — the second half of the two-command catch-up pattern; pair with `init.sh`
- [`../../architecture.md`](../../architecture.md) — the long-session artifact pattern in the harness model
