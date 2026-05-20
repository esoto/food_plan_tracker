class MealItem < ApplicationRecord
  include Tenantable

  belongs_to :meal, inverse_of: :meal_items
  belongs_to :food

  validates :quantity_grams, presence: true, numericality: { greater_than: 0 }

  validate :user_matches_meal_user, if: -> { user_id.present? || meal&.user_id.present? }

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

  def user_matches_meal_user
    return if user_id == meal.user_id

    errors.add(:user_id, "must match the meal's user")
  end
end
