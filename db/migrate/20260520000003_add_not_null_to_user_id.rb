class AddNotNullToUserId < ActiveRecord::Migration[8.1]
  TABLES = [
    :plans,
    :meals,
    :daily_logs,
    :supplements,
    :supplement_schedules,
    :goals,
    :biomarker_entries,
    :checklist_templates,
    :logged_foods,
    :push_subscriptions,
    :reminder_preferences,
    :notification_deliveries,
    :api_tokens,
    :meal_items
  ].freeze

  def up
    # Step 1: Add check constraints with validate: false
    TABLES.each do |table|
      add_check_constraint table, "user_id IS NOT NULL", validate: false, name: "#{table}_user_id_not_null"
    end

    # Step 2: Validate all constraints
    TABLES.each do |table|
      validate_check_constraint table, name: "#{table}_user_id_not_null"
    end

    # Step 3: Change columns to NOT NULL
    TABLES.each do |table|
      change_column_null table, :user_id, false
    end

    # Step 4: Remove check constraints
    TABLES.each do |table|
      remove_check_constraint table, name: "#{table}_user_id_not_null"
    end
  end

  def down
    TABLES.each do |table|
      change_column_null table, :user_id, true
    end
  end
end
