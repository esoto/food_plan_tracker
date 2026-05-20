FactoryBot.define do
  factory :meal_completion do
    association :daily_log
    association :meal
    completed_at { "2026-04-24 11:54:01" }
  end
end
