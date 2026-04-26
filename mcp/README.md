# food-tracker-mcp

A small MCP server that wraps the Food Plan Tracker JSON API at `/api/v1`. Lets Claude (or any MCP client) read today's status and make daily writes — log a weight, mark a meal complete, log a food, switch the day's plan.

## Setup

```bash
cd mcp
npm install
```

## Issue an API token

API tokens are stored in the database (`api_tokens` table — name + SHA-256 digest, plaintext is never persisted). Each client (MCP, phone shortcut, future apps) gets its own token; revoke any one without touching the others.

**Production (against the running container):**

```bash
kamal app exec --reuse "bin/rails api_tokens:create NAME=mcp"
# → "Token (copy now — only shown once): <64-char hex>"
```

**Development:**

```bash
bin/rails api_tokens:create NAME=mcp-dev
```

The plaintext is printed once. Copy it immediately. There is no way to retrieve it later — only revoke and re-issue.

List or revoke:

```bash
kamal api-token-list                                       # production
kamal app exec --reuse "bin/rails api_tokens:revoke NAME=mcp"
```

## Smoke test (before connecting Claude)

```bash
TOKEN='<paste-once>'
curl -s -o /dev/null -w "with token: %{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" \
  https://food.estebansoto.dev/api/v1/today
# → 200

curl -s -o /dev/null -w "no token: %{http_code}\n" https://food.estebansoto.dev/api/v1/today
# → 401
```

## Add to Claude Code (recommended: macOS Keychain)

The token must NOT live as an env var in `~/.claude.json` — `claude mcp get` would print it. Use the keychain wrapper instead:

```bash
# Store the token in macOS Keychain (encrypted at rest, no plaintext file).
security add-generic-password -a "$USER" -s food_plan_tracker_mcp_token -w '<paste-token-once>'

# Register the MCP server pointing at the wrapper script.
claude mcp add food-tracker --scope user \
  -e FOOD_API_BASE_URL=https://food.estebansoto.dev \
  -- /Users/esoto/food_plan_tracker/mcp/bin/run-keychain
```

The wrapper reads the token from Keychain at spawn time, exports `FOOD_API_TOKEN` only inside the spawned Node process, and never echoes it. `claude mcp get food-tracker` will show only `FOOD_API_BASE_URL`.

## Add to Claude Code (alternative: env var, less safe)

If you don't want the keychain dependency, you can pass the token directly:

```bash
claude mcp add food-tracker --scope user \
  -e FOOD_API_BASE_URL=https://food.estebansoto.dev \
  -e FOOD_API_TOKEN='<token>' \
  -- node /Users/esoto/food_plan_tracker/mcp/index.js
```

This stores the token in `~/.claude.json` in plaintext. Anyone running `claude mcp get food-tracker` (including any AI assistant in any Claude Code session) can read it.

## Tools

| Tool | Action |
|---|---|
| `get_today_status` | Read today's plan, targets, consumed macros, weight, completed meals, now-meal, logged foods |
| `get_day_status` | Same shape for any past date |
| `log_weight` | POST a weight measurement (defaults to today) |
| `complete_meal` | Mark a meal complete by name ("Breakfast", "Dinner", ...) |
| `uncomplete_meal` | Reverse |
| `log_food` | Look up a food by partial name + log a serving |
| `delete_logged_food` | Remove a logged-food row by id |
| `set_plan_for_day` | Switch a day to exercise/active/rest |
| `list_goals` | Goal progress (weight, body fat, HDL, ...) |
| `search_foods` | Find canonical food names |

All write tools accept an optional `date` (YYYY-MM-DD) for backfilling past days.

## Rotating a leaked token

If a token is ever exposed (e.g. printed to a chat transcript, committed by mistake), revoke and reissue without disrupting other clients:

```bash
kamal app exec --reuse "bin/rails api_tokens:revoke NAME=mcp"
kamal app exec --reuse "bin/rails api_tokens:create NAME=mcp"
# update keychain:
security delete-generic-password -s food_plan_tracker_mcp_token
security add-generic-password -a "$USER" -s food_plan_tracker_mcp_token -w '<new-token>'
```

## Out of scope

- Editing plan macro targets, goal targets, supplements (use the `/settings` page in the browser)
- CLI tool (only MCP for now)
- Multi-user (single-tenant; tokens are not user-scoped)
