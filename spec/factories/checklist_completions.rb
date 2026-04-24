FactoryBot.define do
  factory :checklist_completion do
    daily_log { nil }
    checklist_template { nil }
    checked { false }
  end
end
