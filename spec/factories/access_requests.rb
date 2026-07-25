FactoryBot.define do
  factory :access_request do
    sequence(:email_address) { |n| "requester#{n}@example.com" }
    message { "Please let me in" }
  end
end
