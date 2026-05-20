FactoryBot.define do
  factory :supplement_completion do
    association :daily_log
    association :supplement
    taken_at { "2026-04-24 11:54:02" }
  end
end
