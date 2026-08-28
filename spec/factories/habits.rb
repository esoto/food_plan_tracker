FactoryBot.define do
  factory :habit do
    user
    label { "MyString" }
    description { "MyString" }
    icon { "MyString" }
    position { 1 }

    trait :quantity do
      kind { :quantity }
      unit { "glasses" }
      target_value { 8 }
    end

    trait :duration do
      kind { :duration }
      unit { "min" }
      target_value { 30 }
    end

    trait :rating do
      kind { :rating }
      rating_scale { 5 }
    end
  end
end
