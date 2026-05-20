# frozen_string_literal: true

class ValidateForeignKeys < ActiveRecord::Migration[8.1]
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
    TABLES.each do |table|
      validate_foreign_key table, :users
    end
  end

  def down
    # Validations cannot be undone
  end
end
