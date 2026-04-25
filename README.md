# Food Plan Tracker

Personal PWA to track adherence to a 5-feeding nutrition plan (CrossFit day
vs. rest day), log weight and biomarkers, and follow a time-of-day supplement
schedule. Mobile-first, installable to iOS home screen, SQLite-backed,
deployable via Kamal.

- **Ruby** 3.4.9 (see `.ruby-version`)
- **Rails** 8.1 + Hotwire (Turbo + Stimulus) + Tailwind CSS v4 + SQLite
- **Auth** single-user, Rails 8 session-based
- **Charts** Chartkick + Chart.js
- **Deploy** Kamal 2 → your VPS, SQLite on a named Docker volume

## Pages

| Route | Purpose |
| ----- | ------- |
| `/` | Dashboard: day-type toggle, macro progress, weight input, goals, 5 rules |
| `/menu` | 5 meals for the active plan, tap to complete |
| `/exchanges` | Tabbed food library with a 0.5/1/1.5/2× macro calculator |
| `/supplements` | Timeline of 13 supplements across 4 time slots |
| `/checklist` | 12 daily habits, streak, and 30-day heatmap |
| `/progress` | 90-day weight curve, 14-day adherence, projection math |
| `/settings` | Edit plan macro targets and goal targets |
| `/days/:date` | Backfill weight or change the day-type for a past day |

## JSON API + MCP

A bearer-token JSON API at `/api/v1` lets external tools read state and
make daily writes (log weight, mark a meal complete, log a food, switch
the plan for a day). Set `API_TOKEN` in `.env`. See [`mcp/README.md`](mcp/README.md)
for the matching MCP server and the `claude mcp add` command.

## Running locally

```bash
bundle install
bin/rails db:prepare  # create + migrate + seed
bin/dev               # Rails server + Tailwind watcher via foreman
```

The app listens on <http://localhost:3000>. Seed credentials default to:

- email: `esoto074@gmail.com`
- password: `changeme-now-please`

Override with `ESTEBAN_EMAIL` / `ESTEBAN_PASSWORD` env vars before seeding.

## Modifying the plan

All nutritional data lives in [`db/seeds.rb`](db/seeds.rb). Edit the `FOODS`,
meal `upsert_meal` calls, `SUPPLEMENTS`, `CHECKLIST`, or `GOALS` arrays and
re-run `bin/rails db:seed` (seeds are idempotent).

## Tests

```bash
bundle exec rspec
```

## Deploy

See [`DEPLOY.md`](DEPLOY.md) for the full setup: prerequisites, the
1Password-driven secrets workflow (`op inject` + master-key sed), the first
`kamal setup` run, iterative `kamal deploy`, ops aliases (logs / console /
shell / seed), and troubleshooting.

The app runs on a single Hetzner VPS shared with several other personal apps.
SSL is terminated by a shared `kamal-proxy`. SQLite databases (primary, cache,
queue, cable) live in a named Docker volume, so data survives redeploys.

## Install on iOS

After deploy, open the app URL in Safari and choose
*Share → Add to Home Screen*. The PWA manifest + service worker give a
standalone-mode launch with offline access to the most recently viewed pages.
