# food-tracker-mcp

A small MCP server that wraps the Food Plan Tracker JSON API at `/api/v1`. Lets Claude (or any MCP client) read today's status and make daily writes — log a weight, mark a meal complete, log a food, switch the day's plan.

## Setup

```bash
cd mcp
npm install
```

The Rails app needs an API token in its `.env`:

```
API_TOKEN=<long-random-string>
```

Restart the Rails server after editing `.env` (dotenv loads at boot).

Use the same token as `FOOD_API_TOKEN` for the MCP server.

## Smoke test (before connecting Claude)

With the Rails server running on `:3000`:

```bash
curl -H "Authorization: Bearer $API_TOKEN" http://localhost:3000/api/v1/today

curl -X POST -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
  -d '{"value": 86.4}' http://localhost:3000/api/v1/weight

# auth gate
curl -i http://localhost:3000/api/v1/today        # → 401
```

## Add to Claude Code

```bash
claude mcp add food-tracker -- node /Users/esoto/food_plan_tracker/mcp/index.js \
  -e FOOD_API_BASE_URL=http://localhost:3000 \
  -e FOOD_API_TOKEN=<the-same-token>
```

Then in any Claude Code session: "what did I eat today?" or "log my weight at 86.4 kg" and Claude will call the right tool.

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

## Out of scope

- Editing plan macro targets, goal targets, supplements (use the [/settings](http://localhost:3000/settings) page in the browser)
- CLI tool (only MCP for now)
- Multi-user (token is global)
