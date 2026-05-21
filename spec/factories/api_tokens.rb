FactoryBot.define do
  factory :api_token do
    user
    sequence(:name) { |n| "Client #{n}" }
  end
end
