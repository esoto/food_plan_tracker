FactoryBot.define do
  factory :logged_food do
    daily_log
    food
    user { daily_log&.user }
    quantity_grams { 100.0 }
    logged_at { Time.current }
  end
end
