class Meal < ApplicationRecord
  include Tenantable

  # Raised when a string assigned to scheduled_time can't be parsed as HH:MM
  # in the 0-23 / 0-59 range. Catchers: Api::V1::MealsController and
  # Api::McpController (in USER_ERRORS) surface it as 422 / isError. The
  # HTML controller leaves it uncaught (a malformed POST is a programming
  # error there since the form is a structured input).
  class InvalidScheduledTime < StandardError; end

  HHMM_FORMAT = /\A\d{1,2}:\d{2}\z/.freeze

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

  # Override the AR setter so all callers (HTML form, REST API, MCP) can pass
  # an "HH:MM" string and have it stored as the project's UTC sentinel Time
  # (Time.utc(2000,1,1,h,m) — see Architecture note). Real Time objects pass
  # through. Bad input raises InvalidScheduledTime rather than silently
  # overflowing the way Ruby's Time.utc(2000,1,1,99,99) does.
  def scheduled_time=(value)
    if value.is_a?(String)
      raise InvalidScheduledTime, "scheduled_time must be HH:MM" unless value.match?(HHMM_FORMAT)

      h, m = value.split(":").map(&:to_i)
      unless (0..23).cover?(h) && (0..59).cover?(m)
        raise InvalidScheduledTime, "scheduled_time must be HH:MM (0-23 hour, 0-59 minute)"
      end

      super(Time.utc(2000, 1, 1, h, m))
    else
      super
    end
  end
end
