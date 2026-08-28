# Wellness Slice 2 — Habit Kinds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Habits gain four kinds (binary / quantity / duration / rating) with per-kind logging UI, a value-based adherence rule, and rating trends — via a rollback-safe expand/contract on `habit_entries.checked`.

**Architecture:** Additive columns on `habits` (kind/unit/target_value/rating_scale) + `habit_entries.value` (fast-default) with a separate backfill. The app reads `value` everywhere after this PR; `checked` is dual-written for one release cycle purely for `kamal rollback` safety and dropped in a later follow-up PR. All writes go through two class methods (`set_value!` upsert, `increment_value!` insert-or-increment) so concurrent taps can't lose updates — **note upsert/raw SQL bypass AR callbacks, so `checked` must be written inside the SQL, not via before_save.** Adherence becomes one SQL predicate; ratings are walled out of adherence/streak/heatmap and get trend presentation on /progress.

**Tech Stack:** Rails 8.1.3.1, PostgreSQL 17, RSpec, Hotwire (no new JS — per-kind controls are plain forms).

## Global Constraints

- Spec: vault note `Personal Brand/Food Plan Tracker/Wellness Pivot.md` (§Section 1, §Slices row 2). Its rules are binding: adherence = `CASE WHEN habits.target_value IS NULL THEN habit_entries.value > 0 ELSE habit_entries.value >= habits.target_value END`, **all-or-nothing** (no fractional credit); **ratings excluded from numerator, denominator, streaks, heatmap**; ratings validated `0..rating_scale`.
- `checked` column is NOT dropped in this PR (post-bake follow-up). Every write path must keep it consistent (`checked = value > 0`) **in SQL** since upserts skip callbacks.
- External API/MCP surface: additive only (new optional fields); nothing existing renamed/removed. Node `mcp/index.js` mirrors the Rails MCP tool schemas.
- Fibrotina supplement↔habit sync: switches to `value:` 1.0/0.0 and no-ops unless the habit is `binary`.
- Migrations: separate files per concern; backfill migration's `down` raises `ActiveRecord::IrreversibleMigration`.
- Worktree `feat/wellness-slice2-kinds` off origin/main; commit per task; full suite + rubocop before PR; `/review-pr` before merge.

---

### Task 1: Migrations + schema

**Files:**
- Create: `db/migrate/<ts>_add_kind_to_habits.rb`, `db/migrate/<ts>_add_value_to_habit_entries.rb`, `db/migrate/<ts>_backfill_habit_entry_values.rb` (three files, generated in this order)
- Modify: `db/schema.rb` (regenerated; watch the dev-DB FK-drop gotcha — revert unrelated churn, keep only additive hunks)

**Interfaces:**
- Produces: `habits.kind:integer(default 0, null:false)`, `habits.unit:string`, `habits.target_value:decimal(7,2)`, `habits.rating_scale:integer`; `habit_entries.value:decimal(6,2)(default 0.0, null:false)` backfilled `1.0 WHERE checked`.

- [ ] **Step 1: Write the three migrations**

```ruby
class AddKindToHabits < ActiveRecord::Migration[8.1]
  def change
    add_column :habits, :kind, :integer, default: 0, null: false
    add_column :habits, :unit, :string
    add_column :habits, :target_value, :decimal, precision: 7, scale: 2
    add_column :habits, :rating_scale, :integer
  end
end
```

```ruby
class AddValueToHabitEntries < ActiveRecord::Migration[8.1]
  def change
    # PG11+ fast-default: instant on existing rows.
    add_column :habit_entries, :value, :decimal, precision: 6, scale: 2, default: 0.0, null: false
  end
end
```

```ruby
class BackfillHabitEntryValues < ActiveRecord::Migration[8.1]
  def up
    execute("UPDATE habit_entries SET value = 1.0 WHERE checked = true")
  end

  def down
    # checked remains authoritative for rollback until it is dropped post-bake;
    # un-backfilling value would lose quantity/duration data written after deploy.
    raise ActiveRecord::IrreversibleMigration
  end
end
```

- [ ] **Step 2: Migrate + verify** — `bin/rails db:migrate && bin/rails db:test:prepare`; then `bin/rails runner 'puts HabitEntry.where(checked: true).where("value <= 0").count'` → 0. Schema diff additive-only.
- [ ] **Step 3: Commit** — `feat(slice2): habit kind columns + habit_entries.value with backfill`

---

### Task 2: Habit model — kind enum + validations + factories

**Files:** Modify `app/models/habit.rb`, `spec/factories/habits.rb`, `spec/models/habit_spec.rb`

**Interfaces:**
- Produces: `Habit.kinds` = binary/quantity/duration/rating; `habit.binary?` etc.; `Habit.scoreable` scope (everything later tasks join on); factory traits `:quantity`, `:duration`, `:rating`.

- [ ] **Step 1: Failing specs** — enum default binary; `scoreable` excludes rating; validations: rating requires `rating_scale` (integer 2..10) and forbids `target_value`/`unit`; binary forbids `unit`/`rating_scale`; `target_value` must be > 0 when present; quantity/duration allow unit+target, forbid rating_scale.
- [ ] **Step 2: Implement** (add to `app/models/habit.rb`):

```ruby
enum :kind, { binary: 0, quantity: 1, duration: 2, rating: 3 }, default: :binary

# Ratings are measurements, not pass/fail — walled out of adherence/streak/heatmap.
scope :scoreable, -> { where.not(kind: :rating) }

validates :target_value, numericality: { greater_than: 0 }, allow_nil: true
validates :rating_scale, presence: true,
  numericality: { only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: 10 },
  if: :rating?
validates :rating_scale, absence: true, unless: :rating?
validates :target_value, absence: true, if: :rating?
validates :unit, absence: true, if: -> { binary? || rating? }
```

- [ ] **Step 3: Factory traits**

```ruby
trait :quantity { kind { :quantity }; unit { "glasses" }; target_value { 8 } }
trait :duration { kind { :duration }; unit { "min" }; target_value { 30 } }
trait :rating   { kind { :rating }; rating_scale { 5 } }
```

- [ ] **Step 4: Green + commit** — `feat(slice2): Habit kinds, scoreable scope, per-kind validations`

---

### Task 3: HabitEntry — value writes (upsert + increment) with in-SQL dual-write

**Files:** Modify `app/models/habit_entry.rb`, `spec/models/habit_entry_spec.rb`

**Interfaces:**
- Produces: `HabitEntry.set_value!(daily_log:, habit:, value:)` and `HabitEntry.increment_value!(daily_log:, habit:, delta:)` — both keep `checked` consistent in SQL and raise `HabitEntry::InvalidValue` on bad input (negative, or rating out of 0..scale). Later tasks call ONLY these from controllers.

- [ ] **Step 1: Failing specs (load-bearing)** — set_value! creates then updates (one row, unique index respected); sets `checked` true iff value > 0 (assert the COLUMN, not the model, after `.reload` — this fails if the SQL dual-write is dropped); increment_value! sums across calls (3 then 2 → 5.0) and flips `checked`; rating value 6 on scale 5 raises InvalidValue and writes nothing; negative delta floors at 0? — NO: negative delta allowed to correct mistakes but result clamps at 0 (`GREATEST(0, ...)`); assert 2 then -5 → 0.0, checked false.
- [ ] **Step 2: Implement**

```ruby
class HabitEntry < ApplicationRecord
  class InvalidValue < StandardError; end

  belongs_to :daily_log
  belongs_to :habit

  validates :habit_id, uniqueness: { scope: :daily_log_id }
  validates :value, numericality: { greater_than_or_equal_to: 0 }

  # All entry writes go through these two so `checked` stays consistent for the
  # one-cycle rollback window (upsert/raw SQL skip AR callbacks — the dual-write
  # MUST live in the SQL). Drop `checked` handling with the column post-bake.
  def self.set_value!(daily_log:, habit:, value:)
    value = validate_value!(habit, value)
    upsert(
      { daily_log_id: daily_log.id, habit_id: habit.id,
        value: value, checked: value > 0 },
      unique_by: %i[daily_log_id habit_id]
    )
  end

  def self.increment_value!(daily_log:, habit:, delta:)
    raise InvalidValue, "delta must be numeric" unless delta.is_a?(Numeric)
    sql = sanitize_sql_array([<<~SQL, daily_log.id, habit.id, delta])
      INSERT INTO habit_entries (daily_log_id, habit_id, value, checked, created_at, updated_at)
      VALUES (?, ?, GREATEST(0, ?), GREATEST(0, ?) > 0, NOW(), NOW())
      ON CONFLICT (daily_log_id, habit_id) DO UPDATE
        SET value = GREATEST(0, habit_entries.value + ?),
            checked = GREATEST(0, habit_entries.value + ?) > 0,
            updated_at = NOW()
    SQL
    connection.execute(sql)
  end

  def self.validate_value!(habit, value)
    value = value.to_f
    raise InvalidValue, "value must be >= 0" if value.negative?
    if habit.rating? && (value < 0 || value > habit.rating_scale)
      raise InvalidValue, "rating must be within 0..#{habit.rating_scale}"
    end
    value
  end
  private_class_method :validate_value!
end
```

Note the VALUES row passes `delta` twice — the sanitize array is `[sql, log.id, habit.id, delta, delta, delta, delta]` (6 placeholders; EXCLUDED.value must NOT be used in DO UPDATE — it is pre-floored by the VALUES clamp and would swallow negative deltas). Keep the dual-write comment.

- [ ] **Step 3: Green + commit** — `feat(slice2): HabitEntry value write paths (upsert + atomic increment, SQL dual-write)`

---

### Task 4: Adherence rewrite (rename to habit_adherence_pct) + all consumers

**Files:** Modify `app/models/daily_log.rb`, `app/models/weekly_summary.rb`, `app/controllers/habits_controller.rb`, plus EVERY caller: `grep -rn "checklist_adherence_pct" app spec` and update all (progress controller/views included). Specs: `spec/models/weekly_summary_spec.rb`, `spec/requests/habits_controller_spec.rb`, new cases in a model spec.

**Interfaces:**
- Produces: `DailyLog#habit_adherence_pct` (old name deleted). Predicate constant `Habit::DONE_PREDICATE` (SQL string) shared by DailyLog + WeeklySummary.

- [ ] **Step 1: Failing specs (the spec's semantics, RED-state checked)** —
  - quantity habit target 8, entry value 3 → 0% (all-or-nothing); value 8 → 100%
  - quantity habit with nil target, value 2 → done (value > 0 fallback)
  - rating habit with entry 5/5 changes NEITHER numerator NOR denominator (two binary habits one done + one rating done → 50%, not 66/33)
  - streak: day at 100% binary + rating logged low → still counts toward streak
  - weekly_summary habit % ignores ratings symmetrically
- [ ] **Step 2: Implement** — in `app/models/habit.rb` add:

```ruby
# All-or-nothing done-ness; nil target falls back to any positive value.
DONE_PREDICATE = <<~SQL.squish.freeze
  CASE WHEN habits.target_value IS NULL THEN habit_entries.value > 0
       ELSE habit_entries.value >= habits.target_value END
SQL
```

`app/models/daily_log.rb` — replace `checklist_adherence_pct` wholesale:

```ruby
def habit_adherence_pct
  total = Habit.for_user(user).kept_on(date).scoreable.count
  return 0 if total.zero?

  done = habit_entries.joins(:habit)
    .merge(Habit.for_user(user).kept_on(date).scoreable)   # kept_on MUST mirror the denominator —
    .where(Habit::DONE_PREDICATE).count                    # else archive-after-done inflates past 100%
  ((done.to_f / total) * 100).round
end
```

`app/models/weekly_summary.rb` — numerator must apply each day's kept_on set symmetrically with the per-day denominator (express kept_on in SQL against daily_logs.date when using one grouped query); an asymmetric numerator counts archived-after-done entries and exceeds 100%. Read the file; only the counting expressions change.

Sweep every `checklist_adherence_pct` caller to `habit_adherence_pct` (habits_controller streak comment included).

- [ ] **Step 3: Green + commit** — `feat(slice2): value-based adherence (habit_adherence_pct), ratings walled out`

---

### Task 5: HabitEntriesController + per-kind daily UI

**Files:** Modify `app/controllers/habit_entries_controller.rb`, `app/views/habits/show.html.erb`; specs `spec/requests/habit_entries_controller_spec.rb`, `spec/system/daily_interactions_spec.rb`.

**Interfaces:**
- Consumes: `HabitEntry.set_value!` / `.increment_value!` / `InvalidValue` (Task 3), `habit.binary?` etc. (Task 2).
- Produces: PATCH `/habit_entries/:id` accepting EITHER `value` (set) OR `delta` (increment). Legacy `checked` param still accepted this cycle (maps to value 1/0) so any stale open tab keeps working.

- [ ] **Step 1: Failing request specs** — `value` param sets; `delta` param increments (two PATCHes sum); `checked=1` legacy → value 1.0; rating out-of-range → redirect with alert, nothing written; delta on binary → treated as set? NO — delta only meaningful for quantity/duration; controller routes ANY `delta` through increment (harmless for binary but UI never sends it) — spec the three param shapes only.
- [ ] **Step 2: Controller**

```ruby
class HabitEntriesController < ApplicationController
  def update
    habit = Current.user.habits.kept.find(params[:id])
    log = daily_log_from_params

    if params[:delta].present?
      HabitEntry.increment_value!(daily_log: log, habit: habit, delta: params[:delta].to_f)
    else
      value =
        if params.key?(:value) then params[:value].to_f
        else (params[:checked] == "1" || params[:checked] == "true") ? 1.0 : 0.0
        end
      HabitEntry.set_value!(daily_log: log, habit: habit, value: value)
    end
    redirect_back fallback_location: habits_path
  rescue HabitEntry::InvalidValue => e
    redirect_back fallback_location: habits_path, alert: e.message
  end
end
```

- [ ] **Step 3: Per-kind view controls** in `app/views/habits/show.html.erb`, inside the existing habit row (replace the single checkbox form; keep the row chrome/icon/label identical):
  - **binary**: existing form but `hidden_field :value, value: entry&.value.to_f > 0 ? 0 : 1`
  - **quantity/duration**: progress line `"#{entry&.value.to_f.round(1).to_s.sub(/\.0$/, '')} / #{habit.target_value.to_f.round(1).to_s.sub(/\.0$/, '')} #{habit.unit}"` (handle nil target: just the value + unit) + two inline `form_with url: habit_entry_path(habit), method: :patch` buttons: `+1` (`hidden_field :delta, value: 1`) and, for duration only, `+15` (`delta: 15`); done-state ring/emerald styling reuses the binary check styling when `Habit::DONE_PREDICATE` semantics hold — compute in Ruby: `done = habit.target_value.nil? ? value > 0 : value >= habit.target_value`
  - **rating**: row of buttons 1..`habit.rating_scale`, each a mini form posting `value: n`; the selected value filled (indigo), others outline. No done-state ring (ratings aren't scored).
  Keep everything inside the same `divide-y` card — one row per habit, controls right-aligned in the row.
- [ ] **Step 4: System spec** — extend `daily_interactions_spec.rb`: quantity +1 tap shows "1 / 8 glasses"; rating tap highlights; binary unchanged. (If Chrome unavailable in sandbox, request specs carry the gate; do not delete system tests.)
- [ ] **Step 5: Green + commit** — `feat(slice2): per-kind logging UI + value/delta entry endpoint`

---

### Task 6: Settings form — create typed habits

**Files:** Modify `app/views/settings/habits/_form.html.erb`, `app/controllers/settings/habits_controller.rb`; spec `spec/requests/settings/habits_controller_spec.rb`.

**Interfaces:**
- Consumes: Habit validations (Task 2).
- Produces: settings create/update permit `:kind, :unit, :target_value, :rating_scale`; **kind is immutable after creation** (update silently ignores `kind` — same lookup-key philosophy as the MCP name rule, and changing kind under existing entries corrupts semantics).

- [ ] **Step 1: Failing specs** — create a quantity habit with unit+target; create rating with scale; update CANNOT change kind (send kind: "rating" on a binary habit → stays binary, 200/redirect not error); validation errors re-render (rating without scale).
- [ ] **Step 2: Controller** — `permit(:label, :description, :icon, :kind, :unit, :target_value, :rating_scale)` on create; on update `permit` the same MINUS `:kind`. **Step 3: Form** — add: kind `form.select` (disabled + hint on edit), `unit` text field, `target_value` number field (step 0.5), `rating_scale` number field; one hint line per field explaining which kinds use it (server-rendered, no JS toggling). Follow the existing form's label/input Tailwind idioms exactly.
- [ ] **Step 4: Green + commit** — `feat(slice2): typed habit creation in settings (kind immutable after create)`

---

### Task 7: Rating trends on /progress

**Files:** Modify `app/controllers/progress_controller.rb`, `app/views/progress/show.html.erb` (new section partial `app/views/progress/_rating_trends.html.erb`); spec `spec/requests/progress_controller_spec.rb`.

**Interfaces:**
- Consumes: `Habit.rating` kind scope (enum gives `Habit.rating`), entries.
- Produces: `@rating_trends` = array of `{ habit:, avg7:, prev_avg7:, points: }` (points = last 14 `[date, value]` pairs).

- [ ] **Step 1: Failing spec** — with a rating habit logged over days, /progress body shows the habit label, a 7-day average to 1 decimal, and an arrow (↑ when avg7 > prev_avg7, ↓ when lower, → when equal/no prior data); section absent when user has no rating habits.
- [ ] **Step 2: Controller** — build in Ruby (14/7-day windows via one query: `HabitEntry.joins(:daily_log, :habit).where(habits: { id: rating_ids }, daily_logs: { date: 13.days.ago.to_date..Date.current, user_id: ... })...`; group in Ruby, no N+1 per habit beyond one query total). **Step 3: View** — card section "Ratings" after the goals section: per habit a row with label, `line_chart points, height: "60px"` (chartkick already in the app), avg + arrow. FULL-span in the lg grid (`lg:my-0 lg:px-0 lg:col-span-2` per the desktop idiom). **Step 4: Green + commit** — `feat(slice2): rating trends on /progress`

---

### Task 8: API v1 + both MCP surfaces (additive) + Fibrotina sync

**Files:** Modify `app/controllers/api/v1/habits_controller.rb`, `app/controllers/api/mcp_controller.rb`, `mcp/index.js`, `app/controllers/supplement_completions_controller.rb`; specs `spec/requests/api/v1/habits_spec.rb`, `spec/requests/api/mcp_spec.rb`, `spec/requests/supplement_completions_controller_spec.rb`.

**Interfaces:**
- Produces: habit JSON gains `kind`, `unit`, `target_value`, `rating_scale` (additive); api/MCP create/update accept them (update ignores `kind` — same immutability as web); `sync_related_habit(supplement, value:, daily_log:)` using `HabitEntry.set_value!`, `return unless habit&.binary?`.

- [ ] **Step 1: Failing specs** — api habits index/create include the four fields; create a rating habit via API; update with kind change → kind unchanged; MCP create_habit with kind quantity works and list_habits shows it (both assert through the Rails MCP; note the Node mirror is schema-only, not spec-covered); sync spec: marking Fibrotina supplement writes value 1.0 (assert entry.value AND entry.checked); a NON-binary habit labeled Fibrotina is not touched by sync (create rating habit "Fibrotina test" → mark supplement → no entry).
- [ ] **Step 2: Implement** — permit/serialize the fields in api/v1 (update excludes :kind); extend the two MCP tool input schemas (Rails TOOLS registry + handlers, and the mirrored inputSchema in `mcp/index.js` — keep descriptions IDENTICAL across surfaces); rewrite `sync_related_habit`:

```ruby
def sync_related_habit(supplement, value:, daily_log: @daily_log)
  return unless supplement.critical
  habit = Current.user.habits.kept.find_by("label ILIKE ?", "%Fibrotina%")
  return unless habit&.binary?
  HabitEntry.set_value!(daily_log: daily_log, habit: habit, value: value)
end
```
Call sites pass `value: 1.0` / `value: 0.0`. (Read the current method first; preserve the `supplement.critical` guard exactly as it exists.)
- [ ] **Step 3: Green + commit** — `feat(slice2): typed habits over API/MCP (additive); Fibrotina sync via set_value!`

---

### Task 9: Full verification + PR

- [ ] **Step 1:** `grep -rn "checklist_adherence_pct" . --exclude-dir=.git --exclude-dir=db` → zero. `grep -rn "\.checked" app --include="*.rb" --include="*.erb"` → only the dual-write SQL in habit_entry.rb and the legacy param branch in habit_entries_controller (list them).
- [ ] **Step 2:** Full `bundle exec rspec` (0 failures) + `bundle exec rubocop` clean.
- [ ] **Step 3 (coordinator):** browser smoke — create one habit of each kind in settings; log: binary toggle, quantity +1 ×3 shows 3/8, duration +15, rating 4/5; /progress shows the rating trend; adherence % on /habits ignores the rating habit. Push, PR, `/review-pr`, merge.
- [ ] **Step 4 (post-bake, SEPARATE follow-up PR days later):** `remove_column :habit_entries, :checked` + delete the dual-write SQL fragments + the legacy `checked` param branch. NOT part of this PR.
