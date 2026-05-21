FactoryBot.define do
  factory :meal_completion do
    daily_log
    meal { association :meal, plan: daily_log.plan }
    completed_at { "2026-04-24 11:54:01" }
  end
end
