class Goal < ApplicationRecord
  METRICS = {
    weight_kg:       0,
    body_fat_pct:    1,
    hdl:             2,
    hs_crp:          3,
    visceral_fat:    4,
    muscle_mass_kg:  5
  }.freeze

  DIRECTIONS = { down: 0, up: 1, preserve: 2 }.freeze

  enum :metric, METRICS
  enum :direction, DIRECTIONS

  has_many :biomarker_entries, -> { order(:recorded_on) }, dependent: :destroy, inverse_of: :goal

  validates :metric, :direction, :display_name, :unit, presence: true
  validates :starting_value, :target_value, presence: true, numericality: true
  validates :metric, uniqueness: true

  def current_value
    biomarker_entries.last&.value || starting_value
  end

  def progress_pct
    span = (starting_value.to_d - target_value.to_d).abs
    return 0 if span.zero?

    current = current_value.to_d
    delta =
      case direction
      when "down"     then (starting_value.to_d - current)
      when "up"       then (current - starting_value.to_d)
      when "preserve" then span - (starting_value.to_d - current).abs
      end
    pct = ((delta / span) * 100).to_f
    pct.clamp(0, 100).round(1)
  end

  def display_progress
    "#{current_value.to_f} / #{target_value.to_f} #{unit}"
  end

  def trend_color
    case metric
    when "weight_kg", "body_fat_pct", "hs_crp", "visceral_fat" then "bg-blue-500"
    when "hdl"                                                  then "bg-emerald-500"
    when "muscle_mass_kg"                                        then "bg-rose-500"
    else "bg-indigo-500"
    end
  end
end
