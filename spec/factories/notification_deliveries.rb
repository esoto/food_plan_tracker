FactoryBot.define do
  factory :notification_delivery do
    title { "Test Notification" }
    fired_at { Time.current }
  end
end
