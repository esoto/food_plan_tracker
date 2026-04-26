class PushSubscription < ApplicationRecord
  # No user_id column on purpose — this app is single-user. If the app ever
  # grows past one user, add a user_id column, scope `PushNotifier#broadcast`
  # by user, and gate `PushSubscriptionsController` writes to the current
  # user's subscriptions only.
  validates :endpoint, :p256dh_key, :auth_key, presence: true

  # Hand the record's keys back in the shape the web-push gem expects.
  def to_push_payload
    {
      endpoint: endpoint,
      p256dh:   p256dh_key,
      auth:     auth_key
    }
  end
end
