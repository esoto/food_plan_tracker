class HabitEntry < ApplicationRecord
  belongs_to :daily_log
  belongs_to :habit

  validates :habit_id, uniqueness: { scope: :daily_log_id }
end
