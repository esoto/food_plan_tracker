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

  ICONS = {
    "Desayuno"        => "🥣",
    "Almuerzo"        => "🍱",
    "Pre-WOD"         => "⚡",
    "Merienda"        => "🍎",
    "Cena Post-WOD"   => "🍽️",
    "Cena"            => "🍽️",
    "Pre-sueño"       => "🌙"
  }.freeze

  def icon
    ICONS[name] || "🍴"
  end
end
