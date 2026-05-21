FactoryBot.define do
  factory :checklist_completion do
    daily_log
    checklist_template { association :checklist_template, user: daily_log.user }
    checked { false }
  end
end
