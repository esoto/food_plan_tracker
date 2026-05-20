# frozen_string_literal: true

class AddForeignKeysOnUserId < ActiveRecord::Migration[8.1]
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
      add_foreign_key table, :users, validate: false
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, :users, if_exists: true
    end
  end
end
