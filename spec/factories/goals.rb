FactoryBot.define do
  factory :goal do
    user
    metric         { :body_fat_pct }
    direction      { :down }
    display_name   { "Body fat" }
    unit           { "%" }
    starting_value { 22.0 }
    target_value   { 19.0 }

    trait :preserve do
      metric         { :muscle_mass_kg }
      direction      { :preserve }
      display_name   { "Muscle mass" }
      unit           { "kg" }
      starting_value { 67.0 }
      target_value   { 67.0 }
    end

    trait :weight do
      metric         { :weight_kg }
      direction      { :down }
      display_name   { "Weight" }
      unit           { "kg" }
      starting_value { 92.0 }
      target_value   { 87.0 }
    end

    trait :with_measurement do
      transient do
        measurement_value { nil }
      end

      after(:create) do |goal, evaluator|
        value = evaluator.measurement_value || goal.starting_value
        create(:biomarker_entry, goal: goal, value: value, recorded_on: Date.current)
      end
    end
  end
end
