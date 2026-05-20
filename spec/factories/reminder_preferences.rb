FactoryBot.define do
  factory :reminder_preference do
    user
    reminder_type { "meal" }
    key { "Breakfast" }
    enabled { true }
  end
end
