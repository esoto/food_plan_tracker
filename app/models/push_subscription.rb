class PushSubscription < ApplicationRecord
  include Tenantable

  # TODO(PER-560): unscoped call sites remain — PushNotifier#broadcast uses
  #   PushSubscription.find_each across all users, and PushSubscriptionsController
  #   create/destroy use unscoped find_or_initialize_by / where(endpoint:).

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
