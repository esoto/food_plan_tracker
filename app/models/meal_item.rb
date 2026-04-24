class MealItem < ApplicationRecord
  belongs_to :meal, inverse_of: :meal_items
  belongs_to :food

  validates :quantity_grams, presence: true, numericality: { greater_than: 0 }

  def ratio
    food.serving_grams.to_d.positive? ? (quantity_grams.to_d / food.serving_grams.to_d) : 0
  end

  def kcal
    (food.kcal * ratio).round
  end

  def protein_g
    (food.protein_g * ratio).round(1)
  end

  def carbs_g
    (food.carbs_g * ratio).round(1)
  end

  def fat_g
    (food.fat_g * ratio).round(1)
  end
end
