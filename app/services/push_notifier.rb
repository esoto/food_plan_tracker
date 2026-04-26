# Sends a Web Push notification to every registered subscription.
#
# Subscriptions whose endpoint has been retired by the browser vendor
# (HTTP 404/410 from the push service) are pruned so the next call
# doesn't keep retrying them.
class PushNotifier
  class NotConfiguredError < StandardError; end

  EXPIRED_STATUSES = [ 404, 410 ].freeze

  def self.broadcast(title:, body:, url: "/")
    new(title: title, body: body, url: url).broadcast
  end

  def initialize(title:, body:, url: "/")
    @title = title
    @body  = body
    @url   = url
  end

  def broadcast
    raise NotConfiguredError, "VAPID keys missing" unless self.class.configured?

    sent = 0
    pruned = 0

    PushSubscription.find_each do |sub|
      payload = JSON.generate(title: @title, body: @body, url: @url)
      WebPush.payload_send(message: payload, vapid: vapid, **sub.to_push_payload)
      sent += 1
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      sub.destroy
      pruned += 1
    rescue WebPush::ResponseError => e
      # 404/410 also surfaced via ResponseError on some endpoints.
      if EXPIRED_STATUSES.include?(e.response.code.to_i)
        sub.destroy
        pruned += 1
      else
        raise
      end
    end

    { sent: sent, pruned: pruned }
  end

  def self.configured?
    public_key.present? && private_key.present?
  end

  def self.public_key
    ENV["VAPID_PUBLIC_KEY"].presence
  end

  def self.private_key
    ENV["VAPID_PRIVATE_KEY"].presence
  end

  def self.subject
    ENV.fetch("VAPID_SUBJECT", "mailto:esoto074@gmail.com")
  end

  private

  def vapid
    {
      public_key:  self.class.public_key,
      private_key: self.class.private_key,
      subject:     self.class.subject
    }
  end
end
