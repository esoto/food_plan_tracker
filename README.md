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

## Deploy to your VPS via Kamal

1. Edit [`config/deploy.yml`](config/deploy.yml): replace `REPLACE_WITH_VPS_IP`
   with the server IP and `REPLACE_WITH_HOSTNAME` with your DNS name.
2. Set local env vars:

   ```bash
   export KAMAL_REGISTRY_PASSWORD=...     # ghcr token with write:packages
   export ESTEBAN_EMAIL=esoto074@gmail.com
   export ESTEBAN_PASSWORD='a-strong-password'
   ```
3. First-time setup:

   ```bash
   bin/kamal setup
   bin/kamal deploy
   bin/kamal seed   # alias → bin/rails db:seed inside the container
   ```

SQLite lives on the `food_plan_tracker_storage` volume so data survives
redeploys. Back up `/rails/storage/production.sqlite3` on any cadence you
like (it's a single file).

## Install on iOS

After deploy, open the app URL in Safari and choose
*Share → Add to Home Screen*. The PWA manifest + service worker give a
standalone-mode launch with offline access to the most recently viewed pages.
