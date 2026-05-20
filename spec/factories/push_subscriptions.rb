FactoryBot.define do
  factory :push_subscription do
    user
    endpoint { "https://test.example.com/push/123" }
    p256dh_key { "test_p256dh" }
    auth_key { "test_auth" }
  end
end
