class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :plans, dependent: :destroy
  has_many :meals, dependent: :destroy
  has_many :daily_logs, dependent: :destroy
  has_many :supplements, dependent: :destroy
  has_many :supplement_schedules, dependent: :destroy
  has_many :goals, dependent: :destroy
  has_many :biomarker_entries, dependent: :destroy
  has_many :checklist_templates, dependent: :destroy
  has_many :logged_foods, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :reminder_preferences, dependent: :destroy
  has_many :notification_deliveries, dependent: :destroy
  has_many :meal_items, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
