FactoryBot.define do
  factory :biomarker_entry do
    goal
    user { goal&.user }
    recorded_on { Date.current }
    value       { 87.0 }
  end
end
