# Deploy

This app runs on a single Hetzner VPS shared with several other personal apps,
deployed via [Kamal 2](https://kamal-deploy.org). SQLite databases live on a
named Docker volume; SSL is terminated by a shared `kamal-proxy` (Let's
Encrypt). No external services — no Redis, no Postgres, no S3.

## Stack on the VPS

| Layer | Choice | Notes |
|---|---|---|
| Host | Hetzner CX23, `178.104.88.183` | Ubuntu 24.04, root SSH disabled, deploy via `deploy@` user |
| Reverse proxy | `basecamp/kamal-proxy` | Shared across all apps on this server; Let's Encrypt auto-issues SSL |
| Container registry | `ghcr.io/esoto/food_plan_tracker` | Pushed during `kamal deploy` |
| App server | Thruster + Puma | Started by `bin/thrust ./bin/rails server` (see `Dockerfile`) |
| Background jobs | Solid Queue, in-Puma | `SOLID_QUEUE_IN_PUMA=true` env in `deploy.yml` |
| Cache | Solid Cache | SQLite at `storage/production_cache.sqlite3` |
| Pub/sub (Action Cable) | Solid Cable | SQLite at `storage/production_cable.sqlite3` |
| Primary DB | SQLite | `storage/production.sqlite3` |
| Volume | `food_plan_tracker_storage:/rails/storage` | All four SQLite files survive redeploys |

## Prerequisites (workstation)

- Docker Desktop running (`docker info` should show a Server section).
- `kamal` 2.11+ (`kamal version`).
- `op` 1Password CLI signed in (`op whoami`).
- The **Food Tracker** item in the **Personal Brand** vault must contain:
  `KAMAL_REGISTRY_PASSWORD` (GHCR PAT with `write:packages`),
  `ADMIN_EMAIL`, `ADMIN_PASSWORD`.
- `config/master.key` present locally (gitignored).

## Secrets

Real values live in `.kamal/secrets`, which is gitignored. Populate it from
1Password + the local master key:

```bash
# 1) Resolve 1Password refs
op inject -i .kamal/secrets.example -o .kamal/secrets --force

# 2) Inline RAILS_MASTER_KEY (Kamal's dotenv parser doesn't run $(...) shell
#    substitution, so we substitute the literal master key into the file)
MK=$(cat config/master.key) && \
  sed -i '' "s|^RAILS_MASTER_KEY=.*|RAILS_MASTER_KEY='${MK}'|" .kamal/secrets && \
  unset MK
```

Verify (label + length only — no values printed):

```bash
kamal secrets print | awk -F= '/^[A-Z_]+=/ {val=$2; gsub(/^"|"$/,"",val); printf "%-28s length=%d\n", $1, length(val)}'
```

Expected lengths: `KAMAL_REGISTRY_PASSWORD=40`, `RAILS_MASTER_KEY=32`,
`ADMIN_EMAIL=18`, `ADMIN_PASSWORD=26` (yours may vary).

> ⚠️ Wrap every value in single quotes inside `.kamal/secrets`. Kamal 2's
> dotenv parser does shell-style `$VAR` interpolation on **unquoted** values
> and silently corrupts secrets containing a literal `$`.

## DNS

`food.estebansoto.dev` is covered by the existing wildcard A-record for
`*.estebansoto.dev → 178.104.88.183` on Porkbun. No new record required.

## First deploy

```bash
kamal setup    # idempotent on existing servers; wires the new app into kamal-proxy
```

`kamal setup` performs:

1. Builds the AMD64 image and pushes to `ghcr.io`.
2. SSHs to `deploy@178.104.88.183`, pulls the image.
3. Creates the `food_plan_tracker_storage` Docker volume on first run.
4. Runs `bin/docker-entrypoint`, which executes `db:prepare` against all four
   production databases — the gem-provided
   [`db/queue_schema.rb`](db/queue_schema.rb),
   [`db/cache_schema.rb`](db/cache_schema.rb),
   [`db/cable_schema.rb`](db/cable_schema.rb) load on first run via the
   `schema_dump:` directives in `config/database.yml`.
5. Runs `db:seed` (idempotent), creating the admin user with
   `ADMIN_EMAIL`/`ADMIN_PASSWORD`.
6. Registers `food.estebansoto.dev` with the shared `kamal-proxy`; Let's
   Encrypt issues an SSL cert.
7. Starts the container; Solid Queue boots inside Puma.

## Iterative deploy

```bash
git pull             # fetch latest main
kamal deploy         # rebuild image, push, rolling-restart container
```

The image is tagged with the current `HEAD` SHA. `db:prepare` runs every boot
and is a no-op when the schema is up to date.

## Operations

```bash
kamal logs            # tail container logs
kamal console         # alias for `bin/rails console` inside the container
kamal shell           # alias for `bash` inside the container
kamal seed            # alias for `bin/rails db:seed` (idempotent re-seed)
kamal app exec --reuse "bin/rails runner 'puts SolidQueue::Job.count'"
```

## Backups

The four SQLite files live in the named volume `food_plan_tracker_storage`.
The current setup does **not** include automated off-site backups (TODO: set
up Hetzner Storage Box replication for `/rails/storage/*.sqlite3`, mirroring
the pattern documented in the [Hetzner VPS Obsidian
note](obsidian://open?file=Personal%20Brand/Infrastructure/Hetzner%20VPS.md)).

Manual snapshot via SSH:

```bash
ssh deploy@178.104.88.183 "docker exec food_plan_tracker-web sqlite3 \
  /rails/storage/production.sqlite3 .dump" > backup-$(date +%Y%m%d).sql
```

## Troubleshooting

**`failed to connect to the docker API at unix:///Users/.../docker.sock`** —
Docker Desktop is not running. Start it: `open -a Docker`, wait for the whale
icon to settle, then re-run.

**`RAILS_MASTER_KEY length=0` after populating `.kamal/secrets`** — Kamal's
dotenv parser doesn't expand `$(...)` shell substitution. Re-run step 2 of the
secrets setup (the `sed` command). Verify with `kamal secrets print`.

**Solid Queue jobs not running** — confirm `SOLID_QUEUE_IN_PUMA=true` in
`config/deploy.yml` (set) and `config/puma.rb`'s `plugin :solid_queue`
guard fires (it does when the env var is set).

**`db:prepare` fails on first deploy with `no such table` for cache/queue/cable** —
the `schema_dump:` directives in `config/database.yml:33,38,43` should load
the gem's schema. If they don't, regenerate via:

```bash
bin/rails solid_queue:install solid_cache:install solid_cable:install
```

and redeploy.

## See also

- [`config/deploy.yml`](config/deploy.yml) — Kamal config.
- [`.kamal/secrets.example`](.kamal/secrets.example) — secret population template.
- Hetzner VPS infrastructure note in Obsidian (`Personal Brand/Infrastructure/Hetzner VPS.md`) — server-level config, shared kamal-proxy setup, deploy-user creation, cost tracking.
