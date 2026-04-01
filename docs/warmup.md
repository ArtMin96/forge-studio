# Budget Window Warmup

Claude Code gives you a token budget that resets every 5 hours. The window starts when you send your first message, **floored to the clock hour**. If your first message is at 10:37, the window starts at 10:00 and expires at 15:00.

Without anchoring, you'll get unpredictable window resets mid-workday.

## How it works

A scheduled remote trigger sends a single cheap Haiku message before your workday starts. This anchors the 5-hour window to a predictable hour so the reset happens when you're not working (e.g., during lunch).

**Cost:** One Haiku "hi" message per weekday. Negligible.

## Example: Armenia (UTC+4), 09:00–18:00, lunch 13:00–14:00

```
08  09  10  11  12  13  14  15  16  17  18
 |======= WINDOW 1 (08-13) =======|
     |====== WORK ======|  LUNCH  |==== WORK ====|
                         |======= WINDOW 2 (13-18) =======|
```

| Time (Armenia) | What happens |
|----------------|----------------------------------------------|
| 08:15          | Warmup fires, window floors to 08:00         |
| 08:00–13:00    | Window 1 — covers entire morning             |
| 13:00          | Window expires at lunch start, not during it  |
| 13:00–14:00    | Lunch — window 2 already active               |
| 14:00          | Return from lunch with fresh budget           |
| 13:00–18:00    | Window 2 — covers entire afternoon            |

The key insight: align the window expiration with the **start** of lunch, not the end. If you exhaust the budget early, the block ends at 13:00 — exactly when lunch begins. With a 09:15 warmup, the block would extend until 14:00, eating into work time.

## Setup

Two options: a **remote trigger** (account-level, no per-machine setup) or a **GitHub Actions workflow** (runs from any repo you own).

---

### Option A: Remote Trigger (recommended)

Account-level — works on any machine where you're logged into the same Anthropic account. No repo required.

In any Claude Code session:

```
"Set up a budget warmup trigger. I work [YOUR HOURS] in [YOUR TIMEZONE] with lunch at [LUNCH TIME]."
```

Claude will create the trigger using the `schedule` skill. Manage it at https://claude.ai/code/scheduled.

<details>
<summary>Manual creation via RemoteTrigger API</summary>

```json
{
  "name": "Workday Warmup",
  "cron_expression": "15 4 * * 1-5",
  "enabled": true,
  "job_config": {
    "ccr": {
      "environment_id": "<your-environment-id>",
      "session_context": {
        "model": "claude-haiku-4-5-20251001",
        "sources": [],
        "allowed_tools": ["Read"]
      },
      "events": [{
        "data": {
          "uuid": "<generate-a-v4-uuid>",
          "session_id": "",
          "type": "user",
          "parent_tool_use_id": null,
          "message": {
            "content": "Say hi. No tools needed, just respond with a single word.",
            "role": "user"
          }
        }
      }]
    }
  }
}
```

</details>

---

### Option B: GitHub Actions Workflow

Runs from any GitHub repo. Useful as a fallback if remote triggers don't anchor the CLI budget window, or if you prefer GitHub-based automation.

1. Copy the template into your repo:

   ```bash
   cp templates/warmup/warmup.yml YOUR_REPO/.github/workflows/warmup.yml
   ```

2. Generate an OAuth token:

   ```bash
   claude setup-token
   ```

3. Add the token as a GitHub secret named `CLAUDE_CODE_OAUTH_TOKEN` in your repo settings.

4. Edit the cron schedule in the workflow file to match your timezone (see table below).

5. Test with a manual dispatch: **Actions → Claude Code Warmup → Run workflow**.

The template is at [`templates/warmup/warmup.yml`](../templates/warmup/warmup.yml).

---

### Calculate your cron time

The cron expression is in UTC. Convert your desired warmup time:

```
(Lunch start hour - 5) + :15 local time → convert to UTC

Examples:
  Lunch 13:00, Armenia (UTC+4)  → 08:15 local → 04:15 UTC → "15 4 * * 1-5"
  Lunch 12:00, Berlin  (UTC+2)  → 07:15 local → 05:15 UTC → "15 5 * * 1-5"
  Lunch 13:00, New York (UTC-4) → 08:15 local → 12:15 UTC → "15 12 * * 1-5"
```

Fire 15 minutes into the hour. This gives the trigger time to execute while still flooring to the target hour.

### Optimize for your schedule

The goal: window 1 expires at **lunch start**, not during work or at lunch end.

| Work pattern | Lunch | Warmup | Window 1 | Expires at | Window 2 |
|---|---|---|---|---|---|
| 09–18 | 13–14 | 08:15 | 08:00–13:00 | Lunch start | 13:00–18:00 |
| 08–17 | 12–13 | 07:15 | 07:00–12:00 | Lunch start | 12:00–17:00 |
| 10–19 | 14–15 | 09:15 | 09:00–14:00 | Lunch start | 14:00–19:00 |

### 4. Verify

After the first trigger fires, run `/usage` in Claude Code. The window should show your anchored start time.

## Management

| Method | Remote Trigger | GitHub Actions |
|--------|---------------|----------------|
| View/edit | https://claude.ai/code/scheduled | Repo → Actions tab |
| Disable | Web UI toggle | Remove workflow or set `enabled: false` |
| Delete | Web UI only | Delete the workflow file |
| Per-machine setup | None (account-level) | Token secret per repo |

## Key facts

- Budget window uses fixed 5-hour boundaries, not sliding
- Token consumption is pooled across all Claude platforms (CLI, web, API)
- Token usage (not message count) determines budget depletion
- A separate weekly cap exists independently of the hourly window

## Credits

GitHub Actions approach based on [vdsmon/claude-warmup](https://github.com/vdsmon/claude-warmup).
