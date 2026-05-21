class ReminderPreference < ApplicationRecord
  include Tenantable

  # Keys are intentionally domain-stable (meal NAME, slot SYMBOL) rather
  # than DB ids. That way a "Breakfast" preference applies across all
  # plans (active/exercise/rest) since they all share the meal name —
  # the user's intent is "remind me about breakfast" not "remind me
  # about meal #17 on plan #2". Trade-off: renaming a meal in /settings
  # silently re-enables a disabled preference.
  REMINDER_TYPES = %w[meal supplement_slot].freeze

  validates :reminder_type, presence: true, inclusion: { in: REMINDER_TYPES }
  validates :key, presence: true, uniqueness: { scope: [:user_id, :reminder_type] }

  # Default behavior: a reminder with no row in the table is enabled.
  # Rows only exist once the user has explicitly toggled at least once.
  def self.enabled?(reminder_type:, key:, user: Current.user)
    record = for_user(user).find_by(reminder_type: reminder_type, key: key)
    record.nil? || record.enabled
  end

  # Idempotent — find or create the row, then flip enabled to the given
  # value.
  def self.set(reminder_type:, key:, enabled:, user: Current.user)
    pref = for_user(user).find_or_initialize_by(reminder_type: reminder_type, key: key)
    pref.enabled = enabled
    pref.save!
    pref
  end
end
