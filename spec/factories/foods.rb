FactoryBot.define do
  factory :food do
    name { "MyString" }
    category { 1 }
    serving_grams { "9.99" }
    kcal { 1 }
    protein_g { "9.99" }
    carbs_g { "9.99" }
    fat_g { "9.99" }
    notes { "MyString" }
  end
end
