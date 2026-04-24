class Food < ApplicationRecord
  CATEGORIES = { protein: 0, carb: 1, fat: 2, vegetable: 3 }.freeze

  enum :category, CATEGORIES

  has_many :meal_items, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :category }
  validates :category, presence: true
  validates :serving_grams, :kcal, :protein_g, :carbs_g, :fat_g, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :alphabetical, -> { order(:name) }

  CATEGORY_LABELS = {
    "protein"   => "Protein",
    "carb"      => "Carbs",
    "fat"       => "Fats",
    "vegetable" => "Veggies"
  }.freeze

  CATEGORY_COLORS = {
    "protein"   => { tint: "bg-rose-50", ring: "ring-rose-200", text: "text-rose-700", dot: "bg-rose-500" },
    "carb"      => { tint: "bg-amber-50", ring: "ring-amber-200", text: "text-amber-700", dot: "bg-amber-500" },
    "fat"       => { tint: "bg-emerald-50", ring: "ring-emerald-200", text: "text-emerald-700", dot: "bg-emerald-500" },
    "vegetable" => { tint: "bg-lime-50", ring: "ring-lime-200", text: "text-lime-700", dot: "bg-lime-500" }
  }.freeze

  def category_label
    CATEGORY_LABELS[category]
  end

  def category_colors
    CATEGORY_COLORS[category]
  end
end
