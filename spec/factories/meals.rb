FactoryBot.define do
  factory :meal do
    plan { nil }
    sequence(:position)
    name { "MyString" }
    # Use the project's UTC sentinel time format (Time.utc(2000,1,1,h,m)) —
    # not a full datetime — so the new Meal#scheduled_time= setter
    # recognizes the value rather than treating it as a malformed HH:MM.
    scheduled_time { Time.utc(2000, 1, 1, 11, 53) }
    target_kcal { 1 }
    target_protein_g { "9.99" }
    target_carbs_g { "9.99" }
    target_fat_g { "9.99" }
  end
end
