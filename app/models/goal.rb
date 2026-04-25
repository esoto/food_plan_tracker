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

  scope :with_measurements, -> { joins(:biomarker_entries).distinct }

  def current_value
    biomarker_entries.last&.value || starting_value
  end

  def has_measurements?
    biomarker_entries.any?
  end

  def show_progress_bar?
    has_measurements?
  end

  def progress_pct
    if preserve?
      # Preserve goals start at 100% and lose ground as |current - starting| grows.
      drift = (starting_value.to_d - current_value.to_d).abs
      tolerance = [ (starting_value.to_d * 0.05).abs, 1 ].max # 5% or 1 unit
      pct = (100 - (drift / tolerance * 100)).to_f
      return pct.clamp(0, 100).round(1)
    end

    span = (starting_value.to_d - target_value.to_d).abs
    return 0 if span.zero?

    current = current_value.to_d
    delta =
      case direction
      when "down" then (starting_value.to_d - current)
      when "up"   then (current - starting_value.to_d)
      end
    pct = ((delta / span) * 100).to_f
    pct.clamp(0, 100).round(1)
  end

  def display_progress
    if has_measurements?
      "#{current_value.to_f} / #{target_value.to_f} #{unit}"
    else
      "— / #{target_value.to_f} #{unit}"
    end
  end

  def progress_note
    if !has_measurements?
      "No readings yet"
    elsif preserve?
      drift = (starting_value.to_d - current_value.to_d).abs
      drift.zero? ? "On target" : "Drift #{drift.to_f.round(1)} #{unit}"
    else
      "#{progress_pct}% toward goal"
    end
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
