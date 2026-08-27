# Wellness Slice 1 — Pure Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename `ChecklistTemplate`→`Habit` and `ChecklistCompletion`→`HabitEntry` across schema, models, controllers, routes, views, MCP/API internals, and specs — with **zero behavior change**.

**Architecture:** Reversible catalog-only migration (`rename_table`/`rename_column`/`rename_index` — Postgres tracks FKs by OID and indexes by attnum, so constraints survive). Then a mechanical sweep of Ruby/ERB/JS references, unifying the naming split the codebase already half-committed to (routes and MCP already say "habit"). The daily page moves from `/checklist` to `/habits` with a 301 (PWA-visible URL).

**Tech Stack:** Rails 8.1, PostgreSQL 17, RSpec, Kamal.

## Global Constraints

- **Zero behavior change.** No new columns, no semantics. The `checked` boolean stays untouched (Slice 2 handles it).
- Public API paths unchanged: `/api/v1/habits` already correct. MCP tool names unchanged (already `*_habit`).
- Old `/checklist` URL must 301 to `/habits` (it is installed in PWAs/bookmarks).
- `spec/` and `db/migrate/` historical migrations are NEVER edited — only the new migration is added.
- Work in a worktree (`feat/wellness-slice1-rename` off origin/main). Never commit to main. Full suite green + rubocop clean before PR; PR reviewed via `/review-pr` before merge.
- Commit after each task with the message given in the task.

**Spec:** vault note `Personal Brand/Food Plan Tracker/Wellness Pivot.md` (§ Slice 1).

---

### Task 1: Reversible rename migration

**Files:**
- Create: `db/migrate/<timestamp>_rename_checklist_to_habits.rb` (generate with `bin/rails g migration RenameChecklistToHabits`)
- Modify: `db/schema.rb` (regenerated — verify only rename-shaped churn)

**Interfaces:**
- Produces: tables `habits`, `habit_entries`; column `habit_entries.habit_id`; indexes `index_habit_entries_on_log_and_habit`, plus renamed single-column indexes.

- [ ] **Step 1: Write the migration**

```ruby
class RenameChecklistToHabits < ActiveRecord::Migration[8.1]
  def change
    rename_table :checklist_templates, :habits
    rename_table :checklist_completions, :habit_entries
    rename_column :habit_entries, :checklist_template_id, :habit_id

    # rename_table/rename_column are catalog-only; FKs (OID) and indexes
    # (attnum) survive. Rename the stale identifiers for readability.
    rename_index :habit_entries, "idx_checklist_completions_on_log_and_template",
                 "idx_habit_entries_on_log_and_habit"
  end
end
```

Note: `rename_table` auto-renames indexes that embed the table name (e.g. `index_checklist_templates_on_user_id` → `index_habits_on_user_id`) and `rename_column` renames `index_checklist_completions_on_checklist_template_id` accordingly. After migrating, check `db/schema.rb` — if any index name still says `checklist`, add an explicit `rename_index` for it in this same migration.

- [ ] **Step 2: Migrate, verify reversibility, re-migrate**

Run: `bin/rails db:migrate && bin/rails db:rollback && bin/rails db:migrate`
Expected: all three succeed; `db/schema.rb` shows `create_table "habits"` and `create_table "habit_entries"` with `habit_id`, no `checklist` strings except historical migration filenames.
⚠️ Dev-DB gotcha (from PR #94): if `schema.rb` regenerates with unrelated FK-drop churn (dev DB missing FKs), revert `db/schema.rb` and hand-apply only the rename hunks; the test DB loads from schema and is authoritative.

- [ ] **Step 3: Prepare test DB**

Run: `bin/rails db:test:prepare`
Expected: clean exit.

- [ ] **Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat(slice1): rename checklist tables to habits/habit_entries (reversible)"
```

---

### Task 2: Models — Habit, HabitEntry + association sweep

**Files:**
- Create (via `git mv`): `app/models/habit.rb` (from `checklist_template.rb`), `app/models/habit_entry.rb` (from `checklist_completion.rb`)
- Modify: `app/models/user.rb:13`, `app/models/daily_log.rb:10,90-96`, `app/models/weekly_summary.rb` (ChecklistCompletion refs), `app/models/concerns/tenantable.rb:11` (comment)

**Interfaces:**
- Produces: `Habit` (scopes `ordered`, `kept`, `for_user`, methods `next_position`, `restore_at_end!` — signatures unchanged), `HabitEntry` (`belongs_to :habit`, uniqueness on `habit_id` scoped to `daily_log_id`), `user.habits`, `daily_log.habit_entries`.

- [ ] **Step 1: Rename model files and contents**

```ruby
# app/models/habit.rb  (body identical to old ChecklistTemplate except names)
class Habit < ApplicationRecord
  include Discardable, Tenantable

  has_many :habit_entries, dependent: :destroy

  validates :label, :position, presence: true

  scope :ordered, -> { order(:position) }

  # Next position to use for a newly created or restored kept habit.
  def self.next_position(user: Current.user)
    (for_user(user).kept.maximum(:position) || -1) + 1
  end

  # Restore a discarded habit at the end of the current order. Position
  # is computed from the *currently kept* set BEFORE clearing discarded_at,
  # so this row appends right after the existing tail (rather than skipping
  # a slot for itself). Atomic — both writes roll back on failure.
  def restore_at_end!
    target_position = self.class.next_position(user: self.user)
    transaction do
      restore!
      update!(position: target_position)
    end
  end
end
```

```ruby
# app/models/habit_entry.rb
class HabitEntry < ApplicationRecord
  belongs_to :daily_log
  belongs_to :habit

  validates :habit_id, uniqueness: { scope: :daily_log_id }
end
```

- [ ] **Step 2: Sweep associations**

- `app/models/user.rb:13` → `has_many :habits, dependent: :destroy`
- `app/models/daily_log.rb:10` → `has_many :habit_entries, dependent: :destroy`
- `app/models/daily_log.rb#checklist_adherence_pct` — **keep the method name** (public API of the model used by 3 consumers; renaming it is gratuitous scope — Slice 2 rewrites this method anyway). Inside it: `ChecklistTemplate` → `Habit`, `checklist_completions` → `habit_entries`.
- `app/models/weekly_summary.rb` — `ChecklistCompletion.where(...)` → `HabitEntry.where(...)`; any `checklist_template` join/count refs → habit equivalents (read the file; only names change).
- `app/models/concerns/tenantable.rb:11` — comment: `ChecklistTemplate` → `Habit`.

- [ ] **Step 3: Run the model specs (expect failures only in spec files' own naming)**

Run: `bundle exec rspec spec/models 2>&1 | tail -5`
Expected: failures referencing `ChecklistTemplate`/`ChecklistCompletion` constants from spec files — that's Task 3's job. No *other* failure classes.

- [ ] **Step 4: Commit**

```bash
git add -A app/models
git commit -m "feat(slice1): Habit + HabitEntry models; association sweep"
```

---

### Task 3: Factories + model/meta specs

**Files:**
- `git mv spec/factories/checklist_templates.rb spec/factories/habits.rb`; `git mv spec/factories/checklist_completions.rb spec/factories/habit_entries.rb`
- `git mv spec/models/checklist_template_spec.rb spec/models/habit_spec.rb`; `git mv spec/models/checklist_completion_spec.rb spec/models/habit_entry_spec.rb`
- Modify: `spec/models/concerns/tenantable_meta_spec.rb` (3 sites: ~:12 TENANTABLE_MODELS list, ~:168 top_level_models, ~:190 `when 'ChecklistTemplate'`), `spec/models/user_spec.rb`, `spec/models/weekly_summary_spec.rb`

**Interfaces:**
- Produces: factories `:habit` (was `:checklist_template`) and `:habit_entry` (was `:checklist_completion`) — all later tasks' specs use these names.

- [ ] **Step 1: Apply the substitution map to all files in this task**

| old | new |
|---|---|
| `ChecklistTemplate` | `Habit` |
| `ChecklistCompletion` | `HabitEntry` |
| `checklist_template_id` | `habit_id` |
| `checklist_templates` | `habits` |
| `checklist_completions` | `habit_entries` |
| `:checklist_template` | `:habit` |
| `:checklist_completion` | `:habit_entry` |

(factory definitions: `factory :habit do ... end`, `factory :habit_entry do ... association :habit ... end` — bodies otherwise unchanged, `checked { false }` stays.)

- [ ] **Step 2: Run model + concern specs**

Run: `bundle exec rspec spec/models 2>&1 | tail -3`
Expected: PASS (0 failures; the pre-existing 5 Tenantable pendings remain).

- [ ] **Step 3: Commit**

```bash
git add -A spec/factories spec/models
git commit -m "test(slice1): rename factories and model specs to habit naming"
```

---

### Task 4: Daily page — HabitsController at /habits, 301 from /checklist

**Files:**
- `git mv app/controllers/checklist_controller.rb app/controllers/habits_controller.rb`
- `git mv app/views/checklist app/views/habits`
- Modify: `config/routes.rb:30`, `app/views/habits/show.html.erb`, `app/controllers/application_controller.rb` (NAV_ITEMS path), `spec/requests/checklist_controller_spec.rb` → `git mv` to `spec/requests/habits_controller_spec.rb`

**Interfaces:**
- Consumes: `Habit`, `HabitEntry`, factories from Tasks 2–3.
- Produces: route helper `habits_path` (the daily page); `redirect /checklist → /habits` (301).

- [ ] **Step 1: Write the failing route/redirect spec** (append to the moved `spec/requests/habits_controller_spec.rb`)

```ruby
describe "legacy /checklist URL" do
  it "301-redirects to /habits" do
    sign_in_as
    get "/checklist"
    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to("/habits")
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec rspec spec/requests/habits_controller_spec.rb 2>&1 | tail -5`
Expected: FAIL (route errors — controller/route not yet renamed).

- [ ] **Step 3: Implement**

`config/routes.rb` line 30 becomes:

```ruby
  resource :habits, only: :show, controller: "habits"
  # Legacy URL — installed PWAs and bookmarks still hit /checklist.
  get "/checklist", to: redirect("/habits", status: 301)
```

`app/controllers/habits_controller.rb`:
```ruby
class HabitsController < ApplicationController
  def show
    @daily_log = today_log
    @habits = Current.user.habits.kept.ordered
    @entries_by_habit = @daily_log.habit_entries.index_by(&:habit_id)
    @last_30_logs = Current.user.daily_logs
      .where(date: 29.days.ago.to_date..Date.current)
      .includes(:habit_entries)
      .index_by(&:date)
    @streak = compute_streak
  end

  private

  STREAK_MAX_DAYS = 365

  # Walks back from today counting consecutive days at >=80% adherence.
  # Capped at STREAK_MAX_DAYS to bound the per-day find_by + adherence calc
  # (each iteration is one query + one count). One year of streak is plenty
  # for the UI; nobody will notice a longer one. Reuses the eager-loaded
  # @last_30_logs to skip the per-day DailyLog lookup for the recent window.
  # Note: checklist_adherence_pct still issues per-day COUNTs (kept_on +
  # checked counts) — bounded by STREAK_MAX_DAYS.
  def compute_streak
    count = 0
    date = Date.current
    STREAK_MAX_DAYS.times do
      log = @last_30_logs[date] || Current.user.daily_logs.find_by(date: date)
      break unless log && log.checklist_adherence_pct >= 80

      count += 1
      date -= 1
    end
    count
  end
end
```

View sweep in `app/views/habits/show.html.erb` (+ `_heatmap.html.erb`): apply the Task-3 substitution map plus `@templates`→`@habits`, `@completions_by_template`→`@entries_by_habit`. `content_for :title` copy stays "Habits" (already user-facing name). Nav: in `app/controllers/application_controller.rb` NAV_ITEMS, change the Habits entry's path from `checklist_path` to `habits_path` (label already "Habits"); grep `app/views/shared/_bottom_nav.html.erb` and `_side_nav.html.erb` for `checklist_path` and update identically.

- [ ] **Step 4: Run request + system specs**

Run: `bundle exec rspec spec/requests/habits_controller_spec.rb spec/system/daily_interactions_spec.rb 2>&1 | tail -3`
Expected: PASS (system spec may need `visit habits_path` / factory-name updates from the map — apply them).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(slice1): daily page becomes HabitsController at /habits with 301 from /checklist"
```

---

### Task 5: HabitEntriesController + Settings::HabitsController

**Files:**
- `git mv app/controllers/checklist_completions_controller.rb app/controllers/habit_entries_controller.rb`
- `git mv app/controllers/settings/checklist_templates_controller.rb app/controllers/settings/habits_controller.rb`
- `git mv app/views/settings/checklist_templates app/views/settings/habits`
- Modify: `config/routes.rb` (:38 drop `controller:` override; :56 rename resource), `app/controllers/supplement_completions_controller.rb` (sync internals), specs: `git mv` `spec/requests/checklist_completions_controller_spec.rb` → `habit_entries_controller_spec.rb`, `spec/requests/settings/checklist_templates_controller_spec.rb` → `spec/requests/settings/habits_controller_spec.rb`

**Interfaces:**
- Consumes: `Habit`, `HabitEntry`, factories.
- Produces: routes `resources :habit_entries, only: :update` (helper `habit_entry_path`) and `namespace :settings { resources :habits ... }` mapping to `Settings::HabitsController`. Web form field names change `checklist_completion[...]`→`habit_entry[...]` (session-only surface, no external clients).

- [ ] **Step 1: Routes**

```ruby
# line 38 area — the override disappears:
    resources :habits do
      member do
        patch :restore
        patch :move_up
        patch :move_down
      end
      collection { get :archived }
    end
# line 56:
  resources :habit_entries,  only: :update
```

- [ ] **Step 2: Controller bodies** — apply the substitution map; class names become `HabitEntriesController` / `Settings::HabitsController`; strong params `params.require(:habit_entry)` / `params.require(:habit)`; redirects use `habits_path` (daily) and `settings_habits_path`. In `supplement_completions_controller.rb#sync_related_habit`: `Current.user.checklist_templates` → `Current.user.habits`, `daily_log.checklist_completions.find_or_initialize_by(checklist_template: template)` → `daily_log.habit_entries.find_or_initialize_by(habit: habit)` (rename local `template`→`habit`). **The `checked:` keyword and boolean stay exactly as-is** (Slice 2 territory).

- [ ] **Step 3: View sweep** — `app/views/settings/habits/*`: substitution map + form models/paths (`form_with model: [:settings, habit]`), plus `app/views/settings/show.html.erb` already links `settings_habits_path` (no change — verify).

- [ ] **Step 4: Run the affected request specs** (after applying the map to the two moved spec files + `spec/requests/supplement_completions_controller_spec.rb`, `spec/requests/discarded_visibility_spec.rb`, `spec/requests/mass_assignment_isolation_spec.rb`, `spec/requests/fresh_user_smoke_spec.rb`)

Run: `bundle exec rspec spec/requests 2>&1 | tail -3`
Expected: PASS except possibly `spec/requests/api/` (Task 6's files — if failing, only on constant names).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(slice1): HabitEntriesController + Settings::HabitsController; drop route override"
```

---

### Task 6: API v1 + both MCP surfaces (internals only)

**Files:**
- Modify: `app/controllers/api/v1/habits_controller.rb`, `app/controllers/api/mcp_controller.rb`, `mcp/index.js`, `db/seeds.rb`
- Specs: `spec/requests/api/v1/habits_spec.rb`, `spec/requests/api/mcp_spec.rb`

**Interfaces:**
- Consumes: `Habit`, `HabitEntry`.
- Produces: NOTHING external changes — routes `/api/v1/habits`, JSON shapes, and MCP tool names/descriptors stay byte-identical. Only internal constant/association references change.

- [ ] **Step 1: Apply the substitution map** to the four app files. In `mcp/index.js` only comments/internal identifiers may mention checklist (tool names are already `*_habit`) — grep `checklist` and update comments; no behavior lines expected. In `db/seeds.rb`, `ChecklistTemplate` seeding block → `Habit` (+ `user.checklist_templates`→`user.habits` if present).

- [ ] **Step 2: Contract guard — verify the API/MCP surface is unchanged**

Run: `git diff -- app/controllers/api mcp/ | grep -E "^[-+].*(\"|')" | grep -viE "habit_entr|Habit\b|checklist" | head`
Expected: no output (no string literals — tool names, JSON keys, route paths — changed).

- [ ] **Step 3: Run API/MCP specs**

Run: `bundle exec rspec spec/requests/api 2>&1 | tail -3`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(slice1): habit naming through API v1 + MCP internals; seeds"
```

---

### Task 7: Full verification, context refresh, PR

**Files:**
- Modify: `.claude/context/` (7 files reference old names — run `/generate-context --refresh 'habit rename'` or hand-edit: `database/indexes.md`, `database/schema-relationships.md`, `database/column-types.md`, `backend/routing.md`, `backend/daily-log-pivot.md`, `backend/model-patterns.md`, `project/domain-language.md`)

- [ ] **Step 1: Zero-reference sweep** (the completeness gate)

Run: `grep -rn "ChecklistTemplate\|ChecklistCompletion\|checklist_template\|checklist_completion" app lib config mcp spec --include="*.rb" --include="*.erb" --include="*.js" | grep -v db/migrate`
Expected: **no output**. (`db/migrate` history and `checklist_adherence_pct` are the only permitted survivors — the method name contains neither banned string.)

- [ ] **Step 2: Full suite + lint**

Run: `bundle exec rspec 2>&1 | tail -3 && bundle exec rubocop 2>&1 | tail -2`
Expected: 0 failures (5 pre-existing pendings), no offenses.

- [ ] **Step 3: Browser smoke (dev server + Playwright, sequential)** — sign in; visit `/habits` (renders list, streak, heatmap); visit `/checklist` (301 → `/habits`); toggle a habit row (entry persists); `/settings/habits` CRUD + archive/restore; supplements page "Mark taken" on Fibrotina still syncs the habit row.

- [ ] **Step 4: Commit context refresh + push + PR**

```bash
git add -A && git commit -m "docs(slice1): refresh .claude/context for habit naming"
git push -u origin feat/wellness-slice1-rename
gh pr create --title "Wellness slice 1: rename checklist → habits (zero behavior change)" --body "..."
```

Then `/review-pr` per house rules; merge on green; deploy is its own decision (spec: slice 1 deploys alone).
