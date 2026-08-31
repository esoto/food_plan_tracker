Slice 3 ledger — plan: docs/superpowers/plans/2026-08-30-wellness-slice3-food-flag.md
Task 2: complete (commits 1a62df8..77d4d04 incl. nav-order fix, re-review clean)
Task 3: complete (Today/Days dashboard gating — macro hero, logged foods, right-now CTA, day/plan toggle gated; today/_rules left ungated — mixed content, gating it would ragged the lg grid)
Task 3: complete (commit 64a72cf, review clean — _rules left ungated by judgment, day_toggle is plan-only so gating whole partial correct)
Task 4: complete (Settings gating — plan macro targets + per-meal targets sections gated, @plans skipped when off, trailing explainer copy made conditional; notifications-alone-row layout for non-admin left as-is — pre-existing, unaffected by the flag)
PROCESS: task gates must run FULL suite (spec/requests-only gate let Task 3 break system specs silently — fixer dispatched)
Task 4: complete (commit 8fc65af, review clean — enabled copy verbatim, no nil-crash paths)
System-spec followup: complete (commit 4737385 — S4a/S4e enabled-user, invite S2 assertion now codifies food-off first-run; full suite 990/0)
Task 5: complete (Notifications + reminder job — NotificationsController @plan nil'd when food off, reusing existing `<% if @plan %>` guard so no view edit needed; UserReminderJob gates fire_meal_reminders on user.food_tracking_enabled? per-user inside Current.set block, supplement reminders unaffected; ReminderPreferencesController write path left ungated by judgment — a disabled user POSTing a meal pref creates a harmless unused row since the job never reads it for them; full suite 994/0, 5 pre-existing Tenantable pendings)
