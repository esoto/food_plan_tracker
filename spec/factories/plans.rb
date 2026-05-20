FactoryBot.define do
  factory :plan do
    user
    name { "Active day" }
    sequence(:slug) { |n| "active-#{n}" }
    target_kcal { 2075 }
    target_protein_g { 180 }
    target_carbs_g { 180 }
    target_fat_g { 80 }
  end
end
