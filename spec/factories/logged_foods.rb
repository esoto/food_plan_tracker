FactoryBot.define do
  factory :logged_food do
    user
    daily_log
    food
    quantity_grams { 100.0 }
    logged_at { Time.current }
  end
end
