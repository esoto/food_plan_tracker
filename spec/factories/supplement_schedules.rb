FactoryBot.define do
  factory :supplement_schedule do
    supplement { nil }
    time_slot { 1 }
    position { 1 }
  end
end
