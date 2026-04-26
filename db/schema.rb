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

ActiveRecord::Schema[8.1].define(version: 2026_04_26_023314) do
  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_api_tokens_on_name", unique: true
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "biomarker_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "goal_id", null: false
    t.date "recorded_on", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 7, scale: 2, null: false
    t.index ["goal_id", "recorded_on"], name: "index_biomarker_entries_on_goal_id_and_recorded_on"
    t.index ["goal_id"], name: "index_biomarker_entries_on_goal_id"
  end

  create_table "checklist_completions", force: :cascade do |t|
    t.boolean "checked", default: false, null: false
    t.integer "checklist_template_id", null: false
    t.datetime "created_at", null: false
    t.integer "daily_log_id", null: false
    t.datetime "updated_at", null: false
    t.index ["checklist_template_id"], name: "index_checklist_completions_on_checklist_template_id"
    t.index ["daily_log_id", "checklist_template_id"], name: "idx_checklist_completions_on_log_and_template", unique: true
    t.index ["daily_log_id"], name: "index_checklist_completions_on_daily_log_id"
  end

  create_table "checklist_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "icon"
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_checklist_templates_on_position"
  end

  create_table "daily_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "notes"
    t.integer "plan_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight_kg", precision: 6, scale: 2
    t.index ["date"], name: "index_daily_logs_on_date", unique: true
    t.index ["plan_id"], name: "index_daily_logs_on_plan_id"
  end

  create_table "foods", force: :cascade do |t|
    t.decimal "carbs_g", precision: 6, scale: 2, default: "0.0", null: false
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.decimal "fat_g", precision: 6, scale: 2, default: "0.0", null: false
    t.integer "kcal", null: false
    t.string "name", null: false
    t.string "notes"
    t.decimal "protein_g", precision: 6, scale: 2, default: "0.0", null: false
    t.decimal "serving_grams", precision: 7, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["category", "name"], name: "index_foods_on_category_and_name"
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
    t.index ["metric"], name: "index_goals_on_metric", unique: true
  end

  create_table "logged_foods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "daily_log_id", null: false
    t.integer "food_id", null: false
    t.datetime "logged_at", null: false
    t.decimal "quantity_grams", precision: 7, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["daily_log_id", "logged_at"], name: "index_logged_foods_on_daily_log_id_and_logged_at"
    t.index ["daily_log_id"], name: "index_logged_foods_on_daily_log_id"
    t.index ["food_id"], name: "index_logged_foods_on_food_id"
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
    t.index ["food_id"], name: "index_meal_items_on_food_id"
    t.index ["meal_id"], name: "index_meal_items_on_meal_id"
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
    t.index ["plan_id", "position"], name: "index_meals_on_plan_id_and_position", unique: true
    t.index ["plan_id"], name: "index_meals_on_plan_id"
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
    t.integer "resource_owner_id"
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
    t.index ["slug"], name: "index_plans_on_slug", unique: true
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
    t.index ["supplement_id"], name: "index_supplement_schedules_on_supplement_id"
    t.index ["time_slot", "position"], name: "index_supplement_schedules_on_time_slot_and_position"
  end

  create_table "supplements", force: :cascade do |t|
    t.string "contraindications"
    t.datetime "created_at", null: false
    t.boolean "critical", default: false, null: false
    t.string "dose", null: false
    t.string "name", null: false
    t.string "notes"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "biomarker_entries", "goals"
  add_foreign_key "checklist_completions", "checklist_templates"
  add_foreign_key "checklist_completions", "daily_logs"
  add_foreign_key "daily_logs", "plans"
  add_foreign_key "logged_foods", "daily_logs"
  add_foreign_key "logged_foods", "foods"
  add_foreign_key "meal_completions", "daily_logs"
  add_foreign_key "meal_completions", "meals"
  add_foreign_key "meal_items", "foods"
  add_foreign_key "meal_items", "meals"
  add_foreign_key "meals", "plans"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "supplement_completions", "daily_logs"
  add_foreign_key "supplement_completions", "supplements"
  add_foreign_key "supplement_schedules", "supplements"
end
