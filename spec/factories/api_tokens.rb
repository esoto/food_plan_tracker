FactoryBot.define do
  factory :api_token do
    sequence(:name) { |n| "Client #{n}" }
  end
end
