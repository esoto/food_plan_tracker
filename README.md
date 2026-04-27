# Food Plan Tracker

Personal PWA to track adherence to a 5-feeding nutrition plan (CrossFit day
vs. rest day), log weight and biomarkers, and follow a time-of-day supplement
schedule. Mobile-first, installable to iOS home screen, PostgreSQL-backed,
deployable via Kamal.

- **Ruby** 3.4.9 (see `.ruby-version`)
- **Rails** 8.1 + Hotwire (Turbo + Stimulus) + Tailwind CSS v4 + PostgreSQL 17
- **Auth** single-user, Rails 8 session-based
- **Charts** Chartkick + Chart.js
- **Push** Web Push (VAPID) with per-meal-time / per-supplement-slot scheduling
- **Deploy** Kamal 2 → shared Hetzner VPS, Postgres on the shared `personal-blog-db` host

## Pages

| Route | Purpose |
| ----- | ------- |
| `/` | Dashboard: day-type toggle, macro progress, weight input, goals, 5 rules |
| `/menu` | 5 meals for the active plan, tap to complete; "Log same as yesterday" copy |
| `/exchanges` | Tabbed food library with a 0.5/1/1.5/2× macro calculator |
| `/supplements` | Timeline of 13 supplements across 4 time slots |
| `/checklist` | 12 daily habits, streak, and 30-day heatmap |
| `/progress` | 90-day weight curve, last-7-days summary card, 14-day adherence, projection math |
| `/notifications` | Push subscriptions, per-reminder toggles, recent delivery log |
| `/settings` | Edit plan + per-meal targets, manage goals/supplements/habits, sign out |
| `/days/:date` | Backfill weight, change day-type, log/edit/delete foods on past days |

## JSON API + MCP

A bearer-token JSON API at `/api/v1` lets external tools read state and
make daily writes (log weight, mark a meal complete, log a food, switch
the plan for a day, copy yesterday's meals, fetch the rolling 7-day summary).
Tokens are DB-backed (`api_tokens` table); issue with
`bin/rails api_tokens:create NAME=<client>`. See [`mcp/README.md`](mcp/README.md)
for the matching MCP server and the `claude mcp add` command. There's also a
remote MCP at `/mcp` (Doorkeeper OAuth) for claude.ai connectors.

## Push reminders

Every minute a Solid Queue ticker fires per-meal-time and per-supplement-slot
push notifications when subscriptions are registered and reminder
preferences allow. Configure VAPID keys via `VAPID_PUBLIC_KEY` /
`VAPID_PRIVATE_KEY` env vars (see `.kamal/secrets.example`). The
`/notifications` page exposes per-reminder toggles, a delivery log, and a
"Send test push" button.

## Running locally

Requires PostgreSQL running locally (defaults to `postgres` user, no
password — same as the expense-tracker setup).

```bash
bundle install
bin/rails db:prepare    # create + migrate + seed
bin/dev                 # Rails server + Tailwind watcher via foreman
```

The app listens on <http://localhost:3000>. Seed credentials default to:

- email: `esoto074@gmail.com`
- password: `changeme-now-please`

Override with `ADMIN_EMAIL` / `ADMIN_PASSWORD` env vars before seeding.

For push reminders to work in dev, also set `VAPID_PUBLIC_KEY` /
`VAPID_PRIVATE_KEY` (generate a dev keypair via
`bundle exec ruby -rweb-push -e 'k=WebPush.generate_key; puts k.public_key, k.private_key'`).
The Claude Preview wrapper at `.claude/launch.json.example` shows the
recommended setup.

## Modifying the plan

All nutritional data lives in [`db/seeds.rb`](db/seeds.rb). Edit the `FOODS`,
meal `upsert_meal` calls, `SUPPLEMENTS`, `CHECKLIST`, or `GOALS` arrays and
re-run `bin/rails db:seed` (seeds are idempotent). Supplements and habits
can also be added / archived from the running app.

## Tests

```bash
bundle exec rspec
```

CI runs the suite against PostgreSQL 17 via a service container; pre-deploy
hook (`.kamal/hooks/pre-deploy`) refuses any deploy with pending migrations.

## Deploy

Deployed via [Kamal 2](https://kamal-deploy.org) on a personal Hetzner VPS
shared with several other apps. SSL is terminated by a shared `kamal-proxy`.
The four production Postgres databases (primary, cache, queue, cable) live
on the shared `personal-blog-db` container, owned by a dedicated
`food_plan_tracker` role. A per-app `prodrigestivill/postgres-backup-local:17`
accessory dumps all four nightly with 30/4/6 retention.

The detailed deploy runbook (workstation prerequisites, the 1Password-driven
secrets workflow, ops aliases, troubleshooting) lives in the private operator
notes — not in this repo.

## Install on iOS

After deploy, open the app URL in Safari and choose
*Share → Add to Home Screen*. The PWA manifest + service worker give a
standalone-mode launch with offline access to the most recently viewed pages
and Web Push notifications (iOS 16.4+).
