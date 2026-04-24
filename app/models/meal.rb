class Meal < ApplicationRecord
  belongs_to :plan, inverse_of: :meals

  has_many :meal_items, -> { order(:display_order, :id) }, dependent: :destroy, inverse_of: :meal
  has_many :foods, through: :meal_items
  has_many :meal_completions, dependent: :destroy

  validates :name, :scheduled_time, :position, presence: true
  validates :position, uniqueness: { scope: :plan_id }, numericality: { only_integer: true, greater_than: 0 }
  validates :target_kcal, :target_protein_g, :target_carbs_g, :target_fat_g,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position) }

  def time_of_day
    scheduled_time.utc.strftime("%-l:%M %p")
  end

  def scheduled_minutes
    scheduled_time.utc.hour * 60 + scheduled_time.utc.min
  end

  # "Now" window: within ±90 min of the current time, and the single closest
  # meal across the plan. Returns false if nothing is within the window.
  NOW_WINDOW = (-90..90).freeze

  def now?(reference = Time.current)
    now_min = reference.hour * 60 + reference.min
    candidates = plan.meals.select { |m| NOW_WINDOW.cover?(m.scheduled_minutes - now_min) }
    candidates.min_by { |m| (m.scheduled_minutes - now_min).abs } == self
  end

  ICONS = {
    "Breakfast"          => "🥣",
    "Lunch"              => "🍱",
    "Pre-workout"        => "⚡",
    "Snack"              => "🍎",
    "Post-workout dinner" => "🍽️",
    "Dinner"             => "🍽️",
    "Pre-sleep"          => "🌙"
  }.freeze

  def icon
    ICONS[name] || "🍴"
  end
end
