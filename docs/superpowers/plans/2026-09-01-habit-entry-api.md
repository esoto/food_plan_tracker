# Habit Entry Write API + MCP `log_habit` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give REST API clients and Claude (via MCP) a write endpoint for habit entries — `POST /api/v1/habits/:habit_id/entries` and a new `log_habit` MCP tool — mirroring the existing HTML `HabitEntriesController#update` write path (`set_value!`/`increment_value!`), plus a same-day read-back on `GET /api/v1/habits?date=`.

**Architecture:** New `Api::V1::HabitEntriesController#create`, nested under the existing `resources :habits` block. It reuses `HabitEntry.set_value!` / `HabitEntry.increment_value!` (the single source of truth for entry writes) and a new `serialize_habit_entry` method on `Api::Concerns::DaySerializer`. The MCP `log_habit` handler is a thin wrapper over the same model calls, registered in `Api::McpController::TOOLS` and mirrored in the Node stdio server (`mcp/index.js`).

**Tech Stack:** Rails 8.1, Api::BaseController (`ActionController::API`) error idioms, Api::McpController JSON-RPC tool registry, Node MCP server with Zod schemas, RSpec request specs.

## Global Constraints

- Tenancy: every Habit/HabitEntry/DailyLog lookup via `Current.user` associations; cross-tenant → 404.
- Timezone: dates resolved in Ruby (`Date.parse`/`Date.current`) via `DailyLog.for`; no PG date arithmetic.
- Error idioms: API `{ error: "..." }` with 400/404/422 per `Api::BaseController`; MCP in-band `tool_error` via `USER_ERRORS`.
- Coverage near 100%; request specs for every new endpoint/branch; rubocop clean; full `bundle exec rspec` green at the end of the PR (baseline 1037 examples / 5 pre-existing Tenantable pendings).
- Delta wins over value when both are present (mirrors `app/controllers/habit_entries_controller.rb:6-10`).
- Do **not** touch `serialize_day` — out of scope (blast radius across 8 surfaces).
- Implementer model guidance line per task: "Sonnet" for multi-file work, "Haiku" for fully-prescribed mechanical tasks (none in this PR — every task touches 2+ files with judgment calls, so all are Sonnet).

## Deviations from brief

None. All design decisions in the brief were directly implementable against the current code (`main @ 7b3ae1d`); `Api::V1::HabitsController`, `Api::BaseController`, `HabitEntry`, and `Api::McpController` all match the brief's line-number references.

---

### Task 1: `POST /api/v1/habits/:habit_id/entries` — controller, route, serializer, error plumbing

**Model: Sonnet**

**Files:**
- Create: `app/controllers/api/v1/habit_entries_controller.rb`
- Create: `spec/requests/api/v1/habit_entries_spec.rb`
- Modify: `config/routes.rb:124-126` (nest `entries` under the `api/v1` `habits` resource block)
- Modify: `app/controllers/api/concerns/day_serializer.rb` (add `serialize_habit_entry`)
- Modify: `app/controllers/api/base_controller.rb:21` (add `rescue_from HabitEntry::InvalidValue`)
- Modify: `app/controllers/api/mcp_controller.rb:21-23` (add `HabitEntry::InvalidValue` to `USER_ERRORS`)

**Interfaces:**
- Consumes: `HabitEntry.set_value!(daily_log:, habit:, value:)` / `HabitEntry.increment_value!(daily_log:, habit:, delta:)` (`app/models/habit_entry.rb:20,28`); `Api::BaseController#daily_log_for(date_param)` (`app/controllers/api/base_controller.rb:40-43`); `Api::Concerns::DaySerializer#serialize_habit` (`app/controllers/api/concerns/day_serializer.rb:144-157`).
- Produces: `Api::Concerns::DaySerializer#serialize_habit_entry(entry)` → `{ habit_id:, date:, value:, done: }`, used by Task 2 (index read-back) and Task 3 (MCP `log_habit` + `list_habits` date arg). The route itself is addressed by literal path string (`"/api/v1/habits/#{habit.id}/entries"`), matching this spec file's existing convention (e.g. `spec/requests/api/v1/habits_spec.rb` uses `"/api/v1/habits"` literals, not path helpers) — no named route helper is relied upon by later tasks.

- [ ] **Step 1: Write the failing request specs**

Create `spec/requests/api/v1/habit_entries_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Api::V1::HabitEntriesController", type: :request do
  before { stub_api_token }

  describe "POST /api/v1/habits/:habit_id/entries" do
    it "sets the value on a binary habit and returns 201 with habit + entry" do
      habit = create(:habit, label: "Walk", position: 0, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 1 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["habit"]["id"]).to eq(habit.id)
      expect(body["entry"]).to include(
        "habit_id" => habit.id,
        "date"     => Date.current.iso8601,
        "value"    => 1.0,
        "done"     => true
      )
    end

    it "accumulates delta across two calls on a quantity habit" do
      habit = create(:habit, :quantity, label: "Water", position: 0, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { delta: 3 } }.to_json,
           headers: auth_headers
      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { delta: 2 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      log = DailyLog.for(Current.user, Date.current)
      entry = HabitEntry.find_by!(daily_log: log, habit: habit)
      expect(entry.reload.value).to eq(5.0)
      expect(response.parsed_body["entry"]["value"]).to eq(5.0)
      expect(response.parsed_body["entry"]["done"]).to eq(false) # target 8, value 5
    end

    it "delta wins over value when both are present" do
      habit = create(:habit, :quantity, label: "Water", position: 0, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 100, delta: 2 } }.to_json,
           headers: auth_headers

      expect(response.parsed_body["entry"]["value"]).to eq(2.0)
    end

    it "value 0 un-checks a binary habit (0 is present?, not blank)" do
      habit = create(:habit, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 1 } }.to_json,
           headers: auth_headers
      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 0 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("entry", "value")).to eq(0.0)
      expect(response.parsed_body.dig("entry", "done")).to be(false)
    end

    it "clamps a negative delta at 0" do
      habit = create(:habit, :quantity, label: "Water", position: 0, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { delta: 2 } }.to_json,
           headers: auth_headers
      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { delta: -5 } }.to_json,
           headers: auth_headers

      expect(response.parsed_body["entry"]["value"]).to eq(0.0)
    end

    it "sets a rating value within scale" do
      habit = create(:habit, :rating, label: "Mood", position: 0, rating_scale: 5, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 4 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["entry"]["value"]).to eq(4.0)
      expect(response.parsed_body["entry"]["done"]).to be_nil
    end

    it "returns 422 and writes nothing when a rating value exceeds the habit's scale" do
      habit = create(:habit, :rating, label: "Mood", position: 0, rating_scale: 5, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 9 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to have_key("error")
      log = DailyLog.for(Current.user, Date.current)
      expect(HabitEntry.find_by(daily_log: log, habit: habit)).to be_nil
    end

    it "returns 422 when a delta is sent for a rating habit" do
      habit = create(:habit, :rating, label: "Mood", position: 0, rating_scale: 5, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { delta: 1 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when the value exceeds the decimal(6,2) column's range" do
      habit = create(:habit, :quantity, label: "Water", position: 0, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 100_000 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 400 when neither value nor delta is present" do
      habit = create(:habit, label: "Walk", position: 0, user: Current.user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: {} }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to have_key("error")
    end

    it "writes to the daily log for the given date param" do
      habit = create(:habit, label: "Walk", position: 0, user: Current.user)
      target_date = Date.current - 2

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 1, date: target_date.iso8601 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      log = DailyLog.for(Current.user, target_date)
      expect(HabitEntry.find_by!(daily_log: log, habit: habit).value).to eq(1.0)
      expect(response.parsed_body["entry"]["date"]).to eq(target_date.iso8601)
    end

    it "returns 404 for an archived habit" do
      habit = create(:habit, label: "Walk", position: 0, user: Current.user, discarded_at: 1.day.ago)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 1 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's habit and writes nothing" do
      other_habit = create(:habit, label: "Theirs", position: 0, user: create(:user))

      post "/api/v1/habits/#{other_habit.id}/entries",
           params: { entry: { value: 1 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(HabitEntry.where(habit: other_habit)).not_to exist
    end
  end
end
```

- [ ] **Step 2: Run the specs to verify they fail**

Run: `bundle exec rspec spec/requests/api/v1/habit_entries_spec.rb`
Expected: FAIL — `ActionController::RoutingError` / `uninitialized constant Api::V1::HabitEntriesController` (no route/controller exists yet).

- [ ] **Step 3: Add the nested route**

In `config/routes.rb`, replace the `api/v1` `habits` block (currently lines 124-126):

```ruby
      resources :habits, only: %i[index create update destroy] do
        member { patch :restore }
      end
```

with:

```ruby
      resources :habits, only: %i[index create update destroy] do
        member { patch :restore }
        resources :entries, only: :create, controller: "habit_entries"
      end
```

This produces `POST /api/v1/habits/:habit_id/entries` → `api/v1/habit_entries#create`, matching the `meals` → `meal_items` nesting pattern immediately above it (`resources :meals ... do resources :meal_items ... end`).

- [ ] **Step 4: Add `serialize_habit_entry` to the DaySerializer concern**

In `app/controllers/api/concerns/day_serializer.rb`, add a new private method after `serialize_habit` (currently ending at line 157):

```ruby
      def serialize_habit_entry(entry)
        habit = entry.habit
        value = entry.value.to_f
        done =
          if habit.rating?
            nil
          else
            habit.target_value.nil? ? value > 0 : value >= habit.target_value
          end

        {
          habit_id: entry.habit_id,
          date:     entry.daily_log.date.iso8601,
          value:    value,
          done:     done
        }
      end
```

This mirrors the done-ness rule already duplicated in `Habit::DONE_PREDICATE` (`app/models/habit.rb:27-30`) and `app/views/habits/show.html.erb:49` (`target.nil? ? value > 0 : value >= target`).

- [ ] **Step 5: Register the `HabitEntry::InvalidValue` rescue on `Api::BaseController`**

In `app/controllers/api/base_controller.rb`, append a new `rescue_from` line right after the existing `rescue_from Date::Error` line (line 21):

```ruby
    rescue_from Date::Error,                     with: :bad_date
    rescue_from HabitEntry::InvalidValue,        with: :invalid_argument
```

Appending at the end is safe per the ordering comment above it (`ArgumentError` must stay registered before `Date::Error`; `HabitEntry::InvalidValue` has no such conflict).

- [ ] **Step 6: Register `HabitEntry::InvalidValue` in the MCP `USER_ERRORS` list**

In `app/controllers/api/mcp_controller.rb`, update the `USER_ERRORS` constant (lines 21-23):

```ruby
    USER_ERRORS = [ ToolArgumentError, ActiveRecord::RecordInvalid,
                   ActiveRecord::RecordNotFound, ArgumentError, KeyError, Date::Error,
                   Meal::InvalidScheduledTime, HabitEntry::InvalidValue ].freeze
```

(This is consumed by Task 3's `log_habit` handler — adding it now keeps the error-plumbing change in one commit.)

- [ ] **Step 7: Write the controller**

Create `app/controllers/api/v1/habit_entries_controller.rb`:

```ruby
module Api
  module V1
    class HabitEntriesController < Api::BaseController
      include Api::Concerns::DaySerializer

      def create
        habit = Current.user.habits.kept.find(params[:habit_id])
        attrs = entry_params
        log   = daily_log_for(attrs[:date])

        if attrs[:delta].present?
          HabitEntry.increment_value!(daily_log: log, habit: habit, delta: attrs[:delta].to_f)
        elsif attrs[:value].present?
          HabitEntry.set_value!(daily_log: log, habit: habit, value: attrs[:value].to_f)
        else
          raise ActionController::ParameterMissing, :value
        end

        entry = HabitEntry.find_by!(daily_log: log, habit: habit)
        render json: { habit: serialize_habit(habit), entry: serialize_habit_entry(entry) },
               status: :created
      end

      private

      def entry_params
        params.require(:entry).permit(:date, :value, :delta)
      end
    end
  end
end
```

Note: REST returns the framework's `param is missing or the value is empty: value` message (400) while MCP's `log_habit` returns `must provide value or delta`. This asymmetry is accepted — a missing param is semantically a 400 and `ParameterMissing` always prepends its prefix; do not try to unify the messages.

- [ ] **Step 8: Run the specs to verify they pass**

Run: `bundle exec rspec spec/requests/api/v1/habit_entries_spec.rb`
Expected: `13 examples, 0 failures`

- [ ] **Step 9: Run rubocop on the changed files**

Run: `bundle exec rubocop app/controllers/api/v1/habit_entries_controller.rb app/controllers/api/base_controller.rb app/controllers/api/mcp_controller.rb app/controllers/api/concerns/day_serializer.rb config/routes.rb spec/requests/api/v1/habit_entries_spec.rb`
Expected: `no offenses detected`

- [ ] **Step 10: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/habit_entries_controller.rb app/controllers/api/concerns/day_serializer.rb app/controllers/api/base_controller.rb app/controllers/api/mcp_controller.rb spec/requests/api/v1/habit_entries_spec.rb
git commit -m "feat(api): add POST /api/v1/habits/:habit_id/entries write endpoint"
```

---

### Task 2: `GET /api/v1/habits?date=` read-back

**Model: Sonnet**

**Files:**
- Modify: `app/controllers/api/v1/habits_controller.rb:6-9` (`index` action)
- Modify: `spec/requests/api/v1/habits_spec.rb` (add a `"GET /api/v1/habits?date="` describe block)

**Interfaces:**
- Consumes: `Api::BaseController#daily_log_for` (Task 1); `Api::Concerns::DaySerializer#serialize_habit_entry` (Task 1); `HabitEntry.includes(:habit, :daily_log).where(daily_log:, habit_id:).index_by(&:habit_id)` (eager-loaded because `serialize_habit_entry` reads `entry.habit` and `entry.daily_log`).
- Produces: no new public interface — additive JSON shape only (`entry: {...} | nil` merged into each habit hash when `date` param present).

- [ ] **Step 1: Write the failing request specs**

Add to `spec/requests/api/v1/habits_spec.rb`, after the existing `describe "GET /api/v1/habits"` block (currently ending at line 53):

```ruby
  describe "GET /api/v1/habits?date=" do
    it "merges each habit's entry for that date, and nil when no entry exists" do
      logged = create(:habit, :quantity, label: "Water", position: 0, user: Current.user)
      unlogged = create(:habit, label: "Walk", position: 1, user: Current.user)
      log = DailyLog.for(Current.user, Date.current)
      HabitEntry.set_value!(daily_log: log, habit: logged, value: 3)

      get "/api/v1/habits?date=#{Date.current.iso8601}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      by_label = response.parsed_body["habits"].index_by { |h| h["label"] }
      expect(by_label["Water"]["entry"]).to include("value" => 3.0, "done" => false)
      expect(by_label["Walk"]["entry"]).to be_nil
    end

    it "does not merge an entry key when date is omitted" do
      create(:habit, label: "Walk", position: 0, user: Current.user)

      get "/api/v1/habits", headers: auth_headers

      expect(response.parsed_body["habits"].first).not_to have_key("entry")
    end
  end
```

- [ ] **Step 2: Run the specs to verify they fail**

Run: `bundle exec rspec spec/requests/api/v1/habits_spec.rb -e "GET /api/v1/habits?date="`
Expected: FAIL — `expected {"id"=>..., ...} to include "entry"` (index doesn't add the key yet).

- [ ] **Step 3: Implement the read-back in `Api::V1::HabitsController#index`**

Replace the `index` action (`app/controllers/api/v1/habits_controller.rb:6-9`):

```ruby
      def index
        scope  = params[:archived].to_s == "true" ? Current.user.habits.discarded.order(:label) : Current.user.habits.kept.ordered
        habits = scope.to_a

        if params[:date].present?
          log = daily_log_for(params[:date])
          entries_by_habit = HabitEntry.includes(:habit, :daily_log).where(daily_log: log, habit_id: habits.map(&:id)).index_by(&:habit_id)
          payload = habits.map { |h| serialize_habit(h).merge(entry: entries_by_habit[h.id]&.then { |e| serialize_habit_entry(e) }) }
        else
          payload = habits.map { |h| serialize_habit(h) }
        end

        render json: { habits: payload }
      end
```

`HabitEntry.includes(:habit, :daily_log)` avoids an N+1: `serialize_habit_entry` reads `entry.habit` and `entry.daily_log`, and a bare `where` would issue one extra query per logged habit for each.

- [ ] **Step 4: Run the specs to verify they pass**

Run: `bundle exec rspec spec/requests/api/v1/habits_spec.rb`
Expected: all examples pass (existing habits_spec examples + 2 new ones).

- [ ] **Step 5: Run rubocop**

Run: `bundle exec rubocop app/controllers/api/v1/habits_controller.rb spec/requests/api/v1/habits_spec.rb`
Expected: `no offenses detected`

- [ ] **Step 6: Commit**

```bash
git add app/controllers/api/v1/habits_controller.rb spec/requests/api/v1/habits_spec.rb
git commit -m "feat(api): merge per-day habit entry into GET /api/v1/habits?date="
```

---

### Task 3: MCP `log_habit` tool + `list_habits` date arg

**Model: Sonnet**

**Files:**
- Modify: `app/controllers/api/mcp_controller.rb` (`handle_list_habits`, new `handle_log_habit`, `TOOLS` registry)
- Modify: `spec/requests/api/mcp_spec.rb` (tools/list count + names, new `log_habit` examples, `list_habits` date example)

**Interfaces:**
- Consumes: `HabitEntry.set_value!` / `HabitEntry.increment_value!` (Task 1); `Api::Concerns::DaySerializer#serialize_habit_entry` (Task 1); `date_arg(args)` / `log_for(args)` helpers (`app/controllers/api/mcp_controller.rb:152-159`).
- Produces: `handle_log_habit(args)` — consumed only by the `TOOLS` registry entry in this task. `mcp/index.js` (Task 4) calls the same wire shape: `POST /api/v1/habits/:id/entries` with body `{ entry: { value, delta, date } }`, and `GET /api/v1/habits?date=` for the `list_habits` extension.

- [ ] **Step 1: Write the failing MCP specs**

In `spec/requests/api/mcp_spec.rb`, update the `tools/list` describe block (lines 110-141) — add `"log_habit"` to the `contain_exactly` list and bump the disabled-user count:

```ruby
  describe "tools/list" do
    it "advertises every tool from the legacy stdio MCP plus list_meals" do
      tools = rpc("tools/list")["result"]["tools"]
      names = tools.map { |t| t["name"] }
      expect(names).to contain_exactly(
        "get_today_status", "get_day_status", "log_weight",
        "complete_meal", "uncomplete_meal", "log_food",
        "delete_logged_food", "set_plan_for_day", "list_goals",
        "search_foods", "create_food", "list_meals",
        "get_weekly_summary", "copy_yesterday_meals",
        "list_supplements", "create_supplement", "update_supplement",
        "archive_supplement", "restore_supplement",
        "list_habits", "create_habit", "update_habit",
        "archive_habit", "restore_habit", "log_habit",
        "update_plan", "update_meal", "update_goal",
        "list_meal_items", "add_meal_item", "update_meal_item", "remove_meal_item"
      )
      tools.each do |tool|
        expect(tool["inputSchema"]).to include("type" => "object")
        expect(tool["description"]).to be_present
      end
    end

    it "still advertises all 32 tools for a food-tracking-disabled user (food tools stay listed)" do
      user.update!(food_tracking_enabled: false)

      tools = rpc("tools/list")["result"]["tools"]
      names = tools.map { |t| t["name"] }
      expect(names.size).to eq(32)
      expect(names).to include("log_food", "get_weekly_summary", "list_habits", "log_habit")
    end
  end
```

Add a new describe block inside `describe "habits management"` (after the `TC-H8` example, before its closing `end` around line 654):

```ruby
      it "log_habit sets a value on a binary habit" do
        habit = create(:habit, label: "Walk", position: 0, user: user)

        result = rpc("tools/call", { name: "log_habit", arguments: { id: habit.id, value: 1 } })["result"]
        expect(result).not_to include("isError" => true)
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["entry"]["value"]).to eq(1.0)
        expect(payload["entry"]["done"]).to be(true)
      end

      it "log_habit accumulates delta on a quantity habit" do
        habit = create(:habit, :quantity, label: "Water", position: 0, user: user)

        rpc("tools/call", { name: "log_habit", arguments: { id: habit.id, delta: 3 } })
        result = rpc("tools/call", { name: "log_habit", arguments: { id: habit.id, delta: 2 } })["result"]

        payload = JSON.parse(result["content"].first["text"])
        expect(payload["entry"]["value"]).to eq(5.0)
      end

      it "log_habit returns isError when a rating value exceeds scale, and writes nothing" do
        habit = create(:habit, :rating, label: "Mood", position: 0, rating_scale: 5, user: user)

        result = rpc("tools/call", { name: "log_habit", arguments: { id: habit.id, value: 9 } })["result"]
        expect(result["isError"]).to be(true)
        expect(HabitEntry.where(habit: habit)).not_to exist
      end

      it "log_habit returns isError on another user's habit" do
        other_habit = create(:habit, label: "Theirs", position: 0, user: other_user)

        result = rpc("tools/call", { name: "log_habit", arguments: { id: other_habit.id, value: 1 } })["result"]
        expect(result["isError"]).to be(true)
        expect(HabitEntry.where(habit: other_habit)).not_to exist
      end

      it "list_habits with a date arg includes each habit's entry for that day" do
        habit = create(:habit, :quantity, label: "Water", position: 0, user: user)
        rpc("tools/call", { name: "log_habit", arguments: { id: habit.id, value: 3 } })

        result = rpc("tools/call", { name: "list_habits", arguments: { date: Date.current.iso8601 } })["result"]
        payload = JSON.parse(result["content"].first["text"])
        found = payload["habits"].find { |h| h["label"] == "Water" }
        expect(found["entry"]).to include("value" => 3.0)
      end
```

- [ ] **Step 2: Run the specs to verify they fail**

Run: `bundle exec rspec spec/requests/api/mcp_spec.rb -e "log_habit" -e "list_habits with a date arg"`
Expected: FAIL — `tool_error("unknown tool: log_habit")` / `isError` true for the happy-path examples; `list_habits` example fails with `undefined method` or a missing `"entry"` key.

- [ ] **Step 3: Add the `handle_log_habit` handler and extend `handle_list_habits`**

In `app/controllers/api/mcp_controller.rb`, replace `handle_list_habits` (currently lines 292-295):

```ruby
    def handle_list_habits(args)
      scope  = args["archived"].to_s == "true" ? Current.user.habits.discarded.order(:label) : Current.user.habits.kept.ordered
      habits = scope.to_a

      if args["date"].present?
        log = log_for(args)
        entries_by_habit = HabitEntry.includes(:habit, :daily_log).where(daily_log: log, habit_id: habits.map(&:id)).index_by(&:habit_id)
        { habits: habits.map { |h| serialize_habit(h).merge(entry: entries_by_habit[h.id]&.then { |e| serialize_habit_entry(e) }) } }
      else
        { habits: habits.map { |t| serialize_habit(t) } }
      end
    end
```

`HabitEntry.includes(:habit, :daily_log)` avoids an N+1: `serialize_habit_entry` reads `entry.habit` and `entry.daily_log`, and a bare `where` would issue one extra query per logged habit for each.

Add `handle_log_habit` immediately after `handle_restore_habit` (currently ending at line 326):

```ruby
    def handle_log_habit(args)
      habit = Current.user.habits.kept.find(args.fetch("id"))
      log   = log_for(args)

      if args["delta"].present?
        HabitEntry.increment_value!(daily_log: log, habit: habit, delta: args["delta"].to_f)
      elsif args["value"].present?
        HabitEntry.set_value!(daily_log: log, habit: habit, value: args["value"].to_f)
      else
        raise ToolArgumentError, "must provide value or delta"
      end

      entry = HabitEntry.find_by!(daily_log: log, habit: habit)
      { habit: serialize_habit(habit), entry: serialize_habit_entry(entry) }
    end
```

- [ ] **Step 4: Register the tool in `TOOLS` and extend `list_habits`' schema**

In the `# ----- Habits -----` section of `TOOLS` (`app/controllers/api/mcp_controller.rb`), update the `list_habits` entry (currently lines 677-684):

```ruby
      {
        name:        "list_habits",
        description: "List habit templates. Default returns active (non-archived) in display order. Pass archived=true for the archived list. Pass date (YYYY-MM-DD) to include each habit's entry for that day.",
        inputSchema: {
          type: "object",
          properties: { "archived" => { type: "boolean", default: false }, "date" => DATE_PROP }
        },
        handler: :handle_list_habits
      },
```

Add a new `log_habit` entry immediately after the `restore_habit` entry (currently ending at line 741, right before the `# ----- Settings: macro targets` comment):

```ruby
      {
        name:        "log_habit",
        description: "Log a habit entry for a day (default today). Pass value to set (binary: 1/0, rating: 1..scale) or delta to add to a quantity/duration habit. Returns the updated entry.",
        inputSchema: {
          type: "object",
          properties: {
            "id"    => { type: "integer", exclusiveMinimum: 0 },
            "value" => { type: "number", minimum: 0 },
            "delta" => { type: "number" },
            "date"  => DATE_PROP
          },
          required: %w[id]
        },
        handler: :handle_log_habit
      },
```

- [ ] **Step 5: Run the specs to verify they pass**

Run: `bundle exec rspec spec/requests/api/mcp_spec.rb`
Expected: all examples pass (baseline + 5 new `log_habit`/`list_habits` examples + updated tools/list count).

- [ ] **Step 6: Run rubocop**

Run: `bundle exec rubocop app/controllers/api/mcp_controller.rb spec/requests/api/mcp_spec.rb`
Expected: `no offenses detected`

- [ ] **Step 7: Commit**

```bash
git add app/controllers/api/mcp_controller.rb spec/requests/api/mcp_spec.rb
git commit -m "feat(mcp): add log_habit tool and list_habits date arg"
```

---

### Task 4: `mcp/index.js` — Node stdio server parity

**Model: Sonnet**

**Files:**
- Modify: `mcp/index.js` (`log_habit` tool registration, `list_habits` date arg)

**Interfaces:**
- Consumes: `POST /api/v1/habits/:id/entries` and `GET /api/v1/habits?date=` (Task 1 + Task 2, byte-identical wire shape to the Rails MCP tools from Task 3).
- Produces: none (leaf file, no other task depends on it).

- [ ] **Step 1: Add the `log_habit` tool registration**

In `mcp/index.js`, add a new `server.registerTool` call immediately after the `restore_habit` registration (currently ending at line 370, right before the `// ----- Settings: macro targets (plan/meal/goal) -----` comment):

```js
server.registerTool(
  "log_habit",
  {
    title: "Log a habit entry",
    description: "Log a habit entry for a day (default today). Pass value to set (binary: 1/0, rating: 1..scale) or delta to add to a quantity/duration habit. Returns the updated entry.",
    inputSchema: {
      id:    z.number().int().positive(),
      value: z.number().min(0).optional(),
      delta: z.number().optional(),
      date:  ISO_DATE.optional()
    }
  },
  async ({ id, ...entry }) => jsonResult(await api("POST", `/api/v1/habits/${id}/entries`, { entry }))
);
```

- [ ] **Step 2: Extend `list_habits` with an optional `date` arg**

Replace the existing `list_habits` registration (currently lines 305-313):

```js
server.registerTool(
  "list_habits",
  {
    title: "List habits",
    description: "List habit templates. Default returns active in display order; pass archived=true for the archived list. Pass date to include each habit's entry for that day.",
    inputSchema: { archived: z.boolean().optional(), date: ISO_DATE.optional() }
  },
  async ({ archived, date }) => {
    const params = new URLSearchParams();
    if (archived) params.set("archived", "true");
    if (date) params.set("date", date);
    const qs = params.toString();
    return jsonResult(await api("GET", `/api/v1/habits${qs ? `?${qs}` : ""}`));
  }
);
```

- [ ] **Step 3: Syntax-check the file**

Run: `node --check mcp/index.js`
Expected: no output, exit code 0.

- [ ] **Step 4: Commit**

```bash
git add mcp/index.js
git commit -m "feat(mcp): mirror log_habit tool and list_habits date arg in the Node stdio server"
```

---

### Task 5: Verification sweep

**Model: Sonnet**

**Files:**
- None (verification-only task; no code changes expected).

**Interfaces:**
- Consumes: everything from Tasks 1-4.
- Produces: nothing — this is the PR's final gate.

- [ ] **Step 1: Run the full test suite**

Run: `bundle exec rspec`
Expected: `1037 examples, 0 failures` plus the new examples from Tasks 1-3 (13 + 2 + 5 = 20 new), and 5 pre-existing Tenantable pendings (i.e. `1057 examples, 0 failures, 5 pending`).

- [ ] **Step 2: Run rubocop across the whole repo**

Run: `bundle exec rubocop`
Expected: `no offenses detected`

- [ ] **Step 3: Grep for the stale "31 tools" count to confirm nothing else references the old total**

Run: `grep -rn "31 tools\|eq(31)" spec/ app/ mcp/`
Expected: no matches (the only prior reference was updated to 32 in Task 3, Step 1).

- [ ] **Step 4: Re-run the Node syntax check as a final gate**

Run: `node --check mcp/index.js`
Expected: no output, exit code 0.

- [ ] **Step 5: Commit (only if Steps 1-4 required a fix; otherwise skip — no diff to commit)**

```bash
git add -A
git commit -m "chore: verification sweep for habit-entry API"
```

## Self-Review notes

- **Spec coverage:** brief items 1-9 (route, params, habit lookup, writes, response shape, error plumbing, read-back, MCP tool, mcp/index.js) each map to a task; item 10 (RED-first spec list) is fully enumerated across Tasks 1-3's Step 1 blocks — every named case (value set, delta accumulate, negative clamp, rating ok/exceeds/delta-rejected, overflow, missing-both, date param, archived 404, cross-tenant 404, read-back with/without date, MCP happy/error, tools/list 32) has a concrete test.
- **Placeholder scan:** no TBD/TODO markers; every step has runnable code and exact commands.
- **Type/name consistency:** `serialize_habit_entry(entry)` (Task 1) is called identically in Task 2's `index` and Task 3's `handle_list_habits`/`handle_log_habit`. `entry_params` (controller-private, Task 1) and `args` (MCP, Task 3) both permit/read `:date`, `:value`, `:delta` — same three keys, same delta-wins-over-value precedence, in both surfaces.
