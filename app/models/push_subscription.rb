class PushSubscription < ApplicationRecord
  include Tenantable

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
