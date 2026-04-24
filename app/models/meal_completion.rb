class MealCompletion < ApplicationRecord
  belongs_to :daily_log
  belongs_to :meal

  validates :completed_at, presence: true
  validates :meal_id, uniqueness: { scope: :daily_log_id }
end
