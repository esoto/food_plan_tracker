FactoryBot.define do
  factory :biomarker_entry do
    goal
    recorded_on { Date.current }
    value       { 87.0 }
  end
end
