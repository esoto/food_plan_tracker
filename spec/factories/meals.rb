FactoryBot.define do
  factory :meal do
    plan { nil }
    position { 1 }
    name { "MyString" }
    scheduled_time { "2026-04-24 11:53:32" }
    target_kcal { 1 }
    target_protein_g { "9.99" }
    target_carbs_g { "9.99" }
    target_fat_g { "9.99" }
  end
end
