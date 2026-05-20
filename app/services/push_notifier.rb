# Sends a Web Push notification to every registered subscription.
#
# Subscriptions whose endpoint has been retired by the browser vendor
# (HTTP 404/410 from the push service) are pruned so the next call
# doesn't keep retrying them.
class PushNotifier
  class NotConfiguredError < StandardError; end

  def self.broadcast(title:, body:, url: "/", user: nil)
    new(title: title, body: body, url: url, user: user).broadcast
  end

  def initialize(title:, body:, url: "/", user: nil)
    @title = title
    @body  = body
    @url   = url
    @user  = user
  end

  def broadcast
    raise NotConfiguredError, "VAPID keys missing" unless self.class.configured?

    sent = 0
    pruned = 0

    payload = JSON.generate(title: @title, body: @body, url: @url)

    PushSubscription.find_each do |sub|
      WebPush.payload_send(message: payload, vapid: vapid, **sub.to_push_payload)
      sent += 1
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      # web-push promotes 404 → InvalidSubscription and 410 →
      # ExpiredSubscription, so a generic ResponseError fallback for
      # those codes would never fire. Anything else (401, 429, 5xx)
      # bubbles up.
      sub.destroy
      pruned += 1
    end

    if @user || Current.user
      NotificationDelivery.create!(
        title:        @title,
        body:         @body,
        url:          @url,
        sent_count:   sent,
        pruned_count: pruned,
        fired_at:     Time.current,
        user:         @user || Current.user
      )
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
