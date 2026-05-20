FactoryBot.define do
  factory :notification_delivery do
    user
    title { "Test Notification" }
    fired_at { Time.current }
  end
end
