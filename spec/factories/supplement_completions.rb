FactoryBot.define do
  factory :supplement_completion do
    daily_log
    supplement { association :supplement, user: daily_log.user }
    taken_at { "2026-04-24 11:54:02" }
  end
end
