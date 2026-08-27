FactoryBot.define do
  factory :habit_entry do
    daily_log
    habit { association :habit, user: daily_log.user }
    checked { false }
  end
end
