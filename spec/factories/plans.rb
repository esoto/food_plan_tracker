FactoryBot.define do
  factory :plan do
    name { "MyString" }
    slug { "MyString" }
    target_kcal { 1 }
    target_protein_g { 1 }
    target_carbs_g { 1 }
    target_fat_g { 1 }
  end
end
