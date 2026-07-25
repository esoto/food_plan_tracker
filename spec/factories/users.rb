FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password12345" }

    trait :admin do
      role { :admin }
    end

    trait :deactivated do
      deactivated_at { 1.day.ago }
    end
  end
end
