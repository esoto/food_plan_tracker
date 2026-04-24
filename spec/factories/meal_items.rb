FactoryBot.define do
  factory :meal_item do
    meal { nil }
    food { nil }
    quantity_grams { "9.99" }
    display_order { 1 }
  end
end
