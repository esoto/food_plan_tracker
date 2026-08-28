# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_27_205809) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "access_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.text "message"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_access_requests_on_email_address", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_api_tokens_on_user_id_and_name", unique: true
    t.index ["user_id", "token_digest"], name: "index_api_tokens_on_user_id_and_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "biomarker_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "goal_id", null: false
    t.date "recorded_on", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.decimal "value", precision: 7, scale: 2, null: false
    t.index ["goal_id", "recorded_on"], name: "index_biomarker_entries_on_goal_id_and_recorded_on"
    t.index ["goal_id"], name: "index_biomarker_entries_on_goal_id"
    t.index ["user_id"], name: "index_biomarker_entries_on_user_id"
  end

  create_table "daily_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "notes"
    t.integer "plan_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.decimal "weight_kg", precision: 6, scale: 2
    t.index ["plan_id"], name: "index_daily_logs_on_plan_id"
    t.index ["user_id", "date"], name: "index_daily_logs_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_daily_logs_on_user_id"
  end

  create_table "foods", force: :cascade do |t|
    t.decimal "carbs_g", precision: 6, scale: 2, default: "0.0", null: false
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id"
    t.decimal "fat_g", precision: 6, scale: 2, default: "0.0", null: false
    t.integer "kcal", null: false
    t.string "name", null: false
    t.string "notes"
    t.decimal "protein_g", precision: 6, scale: 2, default: "0.0", null: false
    t.decimal "serving_grams", precision: 7, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["category", "name"], name: "index_foods_on_category_and_name"
    t.index ["created_by_user_id"], name: "index_foods_on_created_by_user_id"
  end

  create_table "goals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "direction", null: false
    t.string "display_name", null: false
    t.integer "metric", null: false
    t.decimal "starting_value", precision: 7, scale: 2, null: false
    t.decimal "target_value", precision: 7, scale: 2, null: false
    t.string "unit", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "metric"], name: "index_goals_on_user_id_and_metric", unique: true
    t.index ["user_id"], name: "index_goals_on_user_id"
  end

  create_table "habit_entries", force: :cascade do |t|
    t.boolean "checked", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "daily_log_id", null: false
    t.integer "habit_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 6, scale: 2, default: "0.0", null: false
    t.index ["daily_log_id", "habit_id"], name: "idx_habit_entries_on_log_and_habit", unique: true
    t.index ["daily_log_id"], name: "index_habit_entries_on_daily_log_id"
    t.index ["habit_id"], name: "index_habit_entries_on_habit_id"
  end

  create_table "habits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "discarded_at"
    t.string "icon"
    t.integer "kind", default: 0, null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.integer "rating_scale"
    t.decimal "target_value", precision: 7, scale: 2
    t.string "unit"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["discarded_at"], name: "index_habits_kept", where: "(discarded_at IS NULL)"
    t.index ["position"], name: "index_habits_on_position"
    t.index ["user_id"], name: "index_habits_on_user_id"
  end

  create_table "logged_foods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "daily_log_id", null: false
    t.integer "food_id", null: false
    t.datetime "logged_at", null: false
    t.decimal "quantity_grams", precision: 7, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["daily_log_id", "logged_at"], name: "index_logged_foods_on_daily_log_id_and_logged_at"
    t.index ["daily_log_id"], name: "index_logged_foods_on_daily_log_id"
    t.index ["food_id"], name: "index_logged_foods_on_food_id"
    t.index ["user_id"], name: "index_logged_foods_on_user_id"
  end

  create_table "meal_completions", force: :cascade do |t|
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.integer "daily_log_id", null: false
    t.integer "meal_id", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_log_id", "meal_id"], name: "index_meal_completions_on_daily_log_id_and_meal_id", unique: true
    t.index ["daily_log_id"], name: "index_meal_completions_on_daily_log_id"
    t.index ["meal_id"], name: "index_meal_completions_on_meal_id"
  end

  create_table "meal_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "display_order", default: 0, null: false
    t.integer "food_id", null: false
    t.integer "meal_id", null: false
    t.decimal "quantity_grams", precision: 7, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["food_id"], name: "index_meal_items_on_food_id"
    t.index ["meal_id", "food_id"], name: "index_meal_items_on_meal_and_food", unique: true
    t.index ["meal_id"], name: "index_meal_items_on_meal_id"
    t.index ["user_id"], name: "index_meal_items_on_user_id"
  end

  create_table "meals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "plan_id", null: false
    t.integer "position", null: false
    t.time "scheduled_time", null: false
    t.decimal "target_carbs_g", precision: 6, scale: 2, null: false
    t.decimal "target_fat_g", precision: 6, scale: 2, null: false
    t.integer "target_kcal", null: false
    t.decimal "target_protein_g", precision: 6, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["plan_id", "position"], name: "index_meals_on_plan_id_and_position", unique: true
    t.index ["plan_id"], name: "index_meals_on_plan_id"
    t.index ["user_id"], name: "index_meals_on_user_id"
  end

  create_table "notification_deliveries", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "fired_at", null: false
    t.integer "pruned_count", default: 0, null: false
    t.integer "sent_count", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.index ["fired_at"], name: "index_notification_deliveries_on_fired_at"
    t.index ["user_id"], name: "index_notification_deliveries_on_user_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.integer "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in"
    t.string "previous_refresh_token", default: "", null: false
    t.string "refresh_token"
    t.integer "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes"
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "secret", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "target_carbs_g", null: false
    t.integer "target_fat_g", null: false
    t.integer "target_kcal", null: false
    t.integer "target_protein_g", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "slug"], name: "index_plans_on_user_id_and_slug", unique: true
    t.index ["user_id"], name: "index_plans_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.text "endpoint", null: false
    t.string "p256dh_key", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index "user_id, md5(endpoint)", name: "index_push_subscriptions_on_user_and_endpoint_md5", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "reminder_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "key", null: false
    t.string "reminder_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "reminder_type", "key"], name: "idx_on_user_id_reminder_type_key_b3378a9672", unique: true
    t.index ["user_id"], name: "index_reminder_preferences_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "supplement_completions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "daily_log_id", null: false
    t.integer "supplement_id", null: false
    t.datetime "taken_at", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_log_id", "supplement_id"], name: "index_supplement_completions_on_daily_log_id_and_supplement_id", unique: true
    t.index ["daily_log_id"], name: "index_supplement_completions_on_daily_log_id"
    t.index ["supplement_id"], name: "index_supplement_completions_on_supplement_id"
  end

  create_table "supplement_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.integer "supplement_id", null: false
    t.integer "time_slot", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["supplement_id"], name: "index_supplement_schedules_on_supplement_id"
    t.index ["time_slot", "position"], name: "index_supplement_schedules_on_time_slot_and_position"
    t.index ["user_id"], name: "index_supplement_schedules_on_user_id"
  end

  create_table "supplements", force: :cascade do |t|
    t.string "contraindications"
    t.datetime "created_at", null: false
    t.boolean "critical", default: false, null: false
    t.datetime "discarded_at"
    t.string "dose", null: false
    t.string "name", null: false
    t.string "notes"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["discarded_at"], name: "index_supplements_kept", where: "(discarded_at IS NULL)"
    t.index ["user_id"], name: "index_supplements_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "api_tokens", "users"
  add_foreign_key "biomarker_entries", "goals"
  add_foreign_key "biomarker_entries", "users"
  add_foreign_key "daily_logs", "plans"
  add_foreign_key "daily_logs", "users"
  add_foreign_key "foods", "users", column: "created_by_user_id"
  add_foreign_key "goals", "users"
  add_foreign_key "habit_entries", "daily_logs"
  add_foreign_key "habit_entries", "habits"
  add_foreign_key "habits", "users"
  add_foreign_key "logged_foods", "daily_logs"
  add_foreign_key "logged_foods", "foods"
  add_foreign_key "logged_foods", "users"
  add_foreign_key "meal_completions", "daily_logs"
  add_foreign_key "meal_completions", "meals"
  add_foreign_key "meal_items", "foods"
  add_foreign_key "meal_items", "meals"
  add_foreign_key "meal_items", "users"
  add_foreign_key "meals", "plans"
  add_foreign_key "meals", "users"
  add_foreign_key "notification_deliveries", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id"
  add_foreign_key "plans", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "reminder_preferences", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "supplement_completions", "daily_logs"
  add_foreign_key "supplement_completions", "supplements"
  add_foreign_key "supplement_schedules", "supplements"
  add_foreign_key "supplement_schedules", "users"
  add_foreign_key "supplements", "users"
end
