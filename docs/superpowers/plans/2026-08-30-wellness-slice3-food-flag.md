# Wellness Slice 3 — food_tracking_enabled Flag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One per-user boolean (`users.food_tracking_enabled`, default false, existing users backfilled true) that gates the food module: nav, dashboard, settings, notifications, REST API, and MCP tools.

**Architecture:** Flag on User following the existing `deactivated_at` mutator idiom. Surfaces check `Current.user.food_tracking_enabled?` (exposed as a `food_tracking?` helper). Plans/DailyLog data stays seeded for everyone — the flag gates presentation and write surfaces, never the data layer.

**Tech Stack:** Rails 8.1, Tailwind v4, RSpec, existing Api::BaseController / McpController error idioms.

## Global Constraints

- **Plans are ALWAYS seeded** (SeedDefaults + lazy self-heal stay unconditional). `DailyLog belongs_to :plan` is non-nullable (`app/models/daily_log.rb:4`); every wellness surface hangs off DailyLog. This deliberately deviates from the spec's "SeedDefaults skips the 3 plans" line — the spec's own lazy-self-heal note shows the intent is "plans exist when needed", and they are needed always. Documented in the PR.
- **MCP food tools stay in tools/list** (spec: "not hidden from tools/list"); calling one while disabled returns the standard `tool_error` in-band shape with message exactly: `Food tracking is not enabled for this account`. No changes to `mcp/index.js` (static registry stays; it relays server errors).
- **REST food endpoints return 403** `{ error: "food_tracking_disabled" }` matching Api::BaseController's error shape.
- Existing users backfilled `true` in a SEPARATE backfill migration (repo convention); new users default `false`.
- Nav (food off): `Today · Habits · Progress · Supplements` (Progress earns a tab). Nav (food on): unchanged 5 items. Bottom nav uses LITERAL `grid-cols-4` / `grid-cols-5` branch — never interpolated (Tailwind purge).
- Mobile markup pixel-identical for food-ON users everywhere.
- All specs green; controller/request specs for every new endpoint/branch; rubocop clean.
- Wellness surfaces (weight, journal, goals, habits, supplements, biomarkers) must work end-to-end for a food-disabled user — covered by a system-spec journey.

---

### Task 1: Flag column + User model + backfill

**Files:**
- Create: `db/migrate/*_add_food_tracking_enabled_to_users.rb`, `db/migrate/*_backfill_food_tracking_enabled.rb`
- Modify: `app/models/user.rb` (after `reactivate!`, ~:75)
- Test: `spec/models/user_spec.rb`

**Interfaces produces:** `user.food_tracking_enabled?`, `user.enable_food_tracking!`, `user.disable_food_tracking!`.

- [ ] Migration A: `add_column :users, :food_tracking_enabled, :boolean, default: false, null: false`
- [ ] Migration B (separate, backfill): `User.unscoped.update_all(food_tracking_enabled: true)` in `up`; `down` raises `ActiveRecord::IrreversibleMigration` (comment: pre-flag users had food tracking).
- [ ] Model: `def enable_food_tracking! = update!(food_tracking_enabled: true)` / `def disable_food_tracking! = update!(food_tracking_enabled: false)` (match `deactivate!`/`reactivate!` style at user.rb:67-75).
- [ ] Specs: default false on create; mutators flip; `with_admin_insights` still selects the column (users.* — smoke).
- [ ] `git diff db/schema.rb` — only the new column; commit.

### Task 2: Per-user nav + Progress tab

**Files:**
- Modify: `app/controllers/application_controller.rb:69-79` (NAV_ITEMS + nav_items), `app/views/shared/_bottom_nav.html.erb:2`
- Create: `app/views/shared/icons/_chart.html.erb` (reuse the chart icon svg from the Today progress CTA at `app/views/today/show.html.erb:92-104` if one exists there; else a simple line-chart svg matching sibling icon idiom)
- Test: `spec/requests/today_controller_spec.rb` (nav assertions via rendered body) or new `spec/views/shared/_bottom_nav.html.erb_spec.rb`

**Interfaces produces:** `nav_items` returns per-user filtered list; `food_tracking?` helper_method on ApplicationController.

- [ ] Rename NAV_ITEMS to two frozen constants or one list with `food: true` on `:menu`/`:exchanges` and `only_when_food_off: true` on a new `{ key: :progress, path: "/progress", label: "Progress", icon: "chart" }` entry. Fix the stale `:checklist` key → `:habits` while editing.
- [ ] `nav_items`: food on → the 5 current items (order unchanged); food off → `Today · Habits · Progress · Supplements` (this exact order).
- [ ] Add `helper_method :food_tracking?` → `Current.user&.food_tracking_enabled?`.
- [ ] `_bottom_nav.html.erb`: `class="grid <%= nav_items.size == 5 ? "grid-cols-5" : "grid-cols-4" %> ..."` — both literals present in the file so Tailwind keeps them.
- [ ] Side nav (`_side_nav.html.erb`) needs no structural change (vertical flex) — verify it renders the same filtered list.
- [ ] RED specs: disabled user's `GET /` body lacks `/menu` and `/exchanges` links, has `/progress` nav link; enabled user unchanged (all 5, no `/progress` tab). GREEN. Commit.

### Task 3: Dashboard (Today + Days) gating

**Files:**
- Modify: `app/controllers/today_controller.rb:1-19`, `app/views/today/show.html.erb`, `app/controllers/days_controller.rb`, `app/views/days/show.html.erb`
- Test: `spec/requests/today_controller_spec.rb` (`describe "with food tracking disabled"`), `spec/requests/days_controller_spec.rb`

- [ ] TodayController: wrap food ivars (`@plans @plan @meals @completed_meal_ids @now_meal @logged_foods`, lines 3-9 minus `@daily_log`) in `if food_tracking?` (note: `@daily_log` and the plan resolution inside `DailyLog.for` stay — plans exist per Global Constraints; only the presentation ivars are skipped).
- [ ] today/show.html.erb: wrap in `<% if food_tracking? %>`: macro hero (:37-39), logged_foods render (:41), right-now meal CTA (:43-59), and the plan-switcher part of the header day/plan toggle (:33 — read `shared/_day_toggle` first; keep the date part, hide plan switching). Weight, journal, goals, rules, progress-CTA stay. Rules card (`today/_rules`) — read it: if the copy is food-specific, gate it too and note in report.
- [ ] Grid parity: after gating, verify the `lg:grid-cols-2` wrapper (:36) still balances (weight+journal remain a 1-col pair; goals is col-span-2). No ragged row for disabled users; enabled users pixel-identical.
- [ ] days_controller/show: same treatment (it's a near-clone; shared partials already gated — gate the controller ivars + any inline food sections).
- [ ] RED request specs: disabled → no macro hero markers, no menu_path CTA, still has weight input + journal; enabled unchanged. GREEN. Commit.

### Task 4: Settings gating

**Files:**
- Modify: `app/controllers/settings_controller.rb` (skip `@plans` when off), `app/views/settings/show.html.erb`
- Test: `spec/requests/settings_controller_spec.rb`

- [ ] Gate plan macro targets (:20-27) and per-meal targets (:29-48) sections on `food_tracking?`. Goals, templates links, notifications, admin, account stay.
- [ ] Trailing explainer copy (:122+): make the plans/meals sentence conditional.
- [ ] Verify non-admin disabled layout isn't a lone half-width card row (notifications 1-col; admin card absent) — if ragged, give notifications `lg:col-span-2` ONLY under a `unless food_tracking?`+non-admin condition is overkill; simplest acceptable: leave as-is if it renders cleanly, else make notifications span-2 for everyone at lg (check enabled parity — must stay pixel-identical for enabled users, so prefer leave-as-is unless broken).
- [ ] RED/GREEN request specs both states. Commit.

### Task 5: Notifications + reminder job

**Files:**
- Modify: `app/controllers/notifications_controller.rb:11,17-24`, `app/views/notifications/*` (meal reminder prefs UI), `app/jobs/user_reminder_job.rb:30`
- Test: `spec/requests/notifications_controller_spec.rb`, `spec/jobs/user_reminder_job_spec.rb`

- [ ] NotificationsController: skip `@meal_reminders` build when off; view hides the meal-reminders section.
- [ ] UserReminderJob: guard `fire_meal_reminders` with `user.food_tracking_enabled?` (job iterates users — find the per-user loop; supplement reminders unaffected).
- [ ] RED job spec: disabled user gets NO meal push, still gets supplement push (build both reminder types; assert deliveries). GREEN. Commit.

### Task 6: REST API guard

**Files:**
- Create: `app/controllers/api/concerns/requires_food_tracking.rb`
- Modify: the 8 food controllers (`api/v1/`: today, days, plans, foods, meals, meal_items, meal_completions, logged_foods)
- Test: one shared-example spec included in each food controller's spec + a non-gated control (habits/weight)

- [ ] Concern: `before_action :require_food_tracking!`; method renders `json: { error: "food_tracking_disabled" }, status: :forbidden` unless `Current.user.food_tracking_enabled?` (match base_controller error idiom at :45-63).
- [ ] Include in exactly the 8 food controllers. Goals, weight, supplements, habits, weekly_summary NOT gated (weekly_summary is mixed — stays available; its meal fields just read empty-ish data; note as accepted).
- [ ] Shared example `behaves like "food-gated endpoint"`: disabled token user → 403 with that exact body on index/representative action; enabled → normal. Add control spec asserting /api/v1/habits still 200 for disabled user.
- [ ] RED → GREEN. Commit.

### Task 7: MCP guard

**Files:**
- Modify: `app/controllers/api/mcp_controller.rb` (TOOLS registry :443+, call_tool :121-132)
- Test: `spec/requests/api/mcp_spec.rb`

- [ ] Tag the 18 food tools with `food: true` in TOOLS (exact list from the slice-3 map: get_today_status, get_day_status, complete_meal, uncomplete_meal, copy_yesterday_meals, log_food, delete_logged_food, set_plan_for_day, search_foods, create_food, list_meals, update_plan, update_meal, list_meal_items, add_meal_item, update_meal_item, remove_meal_item — and get_weekly_summary is NOT gated, it stays agnostic-available).
- [ ] call_tool: after tool lookup, `return tool_error("Food tracking is not enabled for this account") if tool[:food] && !Current.user.food_tracking_enabled?` (before `send`).
- [ ] tool_descriptors UNCHANGED (spec mandate: not hidden from tools/list) — the existing 31-name contain_exactly spec at mcp_spec.rb:109-121 must keep passing untouched.
- [ ] RED specs: disabled user calls log_food → isError true, exact message, no LoggedFood created; disabled user calls list_habits → works; tools/list still returns all 31 for disabled user. GREEN. Commit.

### Task 8: Admin toggle

**Files:**
- Modify: `app/controllers/admin/users_controller.rb`, `config/routes.rb:87-95`, `app/views/admin/users/index.html.erb` (:53-63 pills, :71-98 buttons)
- Test: `spec/requests/admin/users_controller_spec.rb`

- [ ] Routes: `patch :enable_food_tracking` / `patch :disable_food_tracking` member routes (match promote/demote style).
- [ ] Controller actions calling the Task-1 mutators + redirect with flash (flash on destroy-style actions per repo convention). NOT in `forbid_self` list (self-toggling is safe).
- [ ] View: "Food" pill next to role pills; toggle `button_to` beside Promote/Demote showing the opposite action label.
- [ ] Specs: admin can toggle both ways; member gets 404/redirect (match existing admin authz spec pattern); pill/button render. RED → GREEN. Commit.

### Task 9: Disabled-user journey + verification sweep

**Files:**
- Create: `spec/system/food_disabled_journey_spec.rb`
- Test: full suite

- [ ] System spec (real driver, mirror slice-2 system specs): admin disables a user's food tracking → that user signs in → sees 4-tab nav → logs weight + journal note + habit + supplement from Today/Habits/Supplements → visits /progress via nav tab → never sees Menu/Foods links. Note: `spec/support/system_authentication_helper.rb:15` seeds defaults — plans exist, which is correct per Global Constraints.
- [ ] Direct-URL probe in a request spec: disabled user GET /menu and /exchanges → decide-and-implement redirect to root with alert (HTML pages; pick redirect over 404 — softer for a user whose flag was flipped mid-session; assert it).
- [ ] Sweep: grep for remaining unguarded food surfaces (`menu_controller exchanges_controller foods_controller logged_foods_controller meals_controller meal_completions_controller plans_controller days_controller` HTML side — all need the same before_action redirect guard; add via a shared `RequiresFoodTrackingHtml` concern or ApplicationController method).
- [ ] Full `bundle exec rspec` green, rubocop clean, tailwind rebuild if new classes. Commit.

## Self-Review notes
- HTML food controllers get their guard in Task 9's sweep (redirect), REST in Task 6 (403), MCP in Task 7 (tool_error) — three shapes for three surface types, each matching its surface's convention.
- WeeklySummary meal_completion_pct stays computed for all (accepted; /progress view shows it only where it renders today — leave, it reads 0/None for foodless days).
- Deviation from spec (seeding) is deliberate and documented; MCP list behavior follows spec exactly.
