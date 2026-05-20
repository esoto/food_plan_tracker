FactoryBot.define do
  factory :supplement_schedule do
    user
    supplement
    time_slot { 1 }
    position { 1 }
  end
end
