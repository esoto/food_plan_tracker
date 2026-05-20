FactoryBot.define do
  factory :daily_log do
    user
    date { "2026-04-24" }
    plan { nil }
    weight_kg { "9.99" }
    notes { "MyText" }
  end
end
