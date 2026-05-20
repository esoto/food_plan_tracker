FactoryBot.define do
  factory :checklist_completion do
    association :daily_log
    association :checklist_template
    checked { false }
  end
end
