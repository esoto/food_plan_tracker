require "rails_helper"

RSpec.describe PushNotifier do
  # ENV mutations are scoped per-example. stub_const("ENV", ...) is an
  # anti-pattern (replaces the constant with a Hash, breaks ENV.fetch
  # semantics).
  around do |example|
    saved = ENV.to_h.slice("VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY")
    example.run
  ensure
    %w[VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY].each { |k| ENV.delete(k) }
    saved.each { |k, v| ENV[k] = v }
  end

  describe ".configured?" do
    it "is false when both env vars are missing" do
      ENV.delete("VAPID_PUBLIC_KEY")
      ENV.delete("VAPID_PRIVATE_KEY")
      expect(described_class.configured?).to be false
    end

    it "is false when only the public key is set" do
      ENV["VAPID_PUBLIC_KEY"]  = "PUB"
      ENV.delete("VAPID_PRIVATE_KEY")
      expect(described_class.configured?).to be false
    end

    it "is false when only the private key is set" do
      ENV.delete("VAPID_PUBLIC_KEY")
      ENV["VAPID_PRIVATE_KEY"] = "PRV"
      expect(described_class.configured?).to be false
    end

    it "is true when both keys are set" do
      ENV["VAPID_PUBLIC_KEY"]  = "PUB"
      ENV["VAPID_PRIVATE_KEY"] = "PRV"
      expect(described_class.configured?).to be true
    end
  end

  describe ".broadcast" do
    let(:user) { create(:user) }
    let!(:sub_a) { PushSubscription.create!(endpoint: "https://fcm.example/A", p256dh_key: "p", auth_key: "a", user: user) }
    let!(:sub_b) { PushSubscription.create!(endpoint: "https://fcm.example/B", p256dh_key: "p", auth_key: "a", user: user) }

    before do
      ENV["VAPID_PUBLIC_KEY"]  = "PUB"
      ENV["VAPID_PRIVATE_KEY"] = "PRV"
      Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
    end

    it "calls WebPush.payload_send for each subscription" do
      expect(WebPush).to receive(:payload_send).twice.and_return(true)

      result = described_class.broadcast(title: "Hi", body: "World", url: "/menu")
      expect(result).to eq(sent: 2, pruned: 0)
    end

    it "writes a NotificationDelivery row recording the broadcast" do
      allow(WebPush).to receive(:payload_send).and_return(true)

      expect {
        described_class.broadcast(title: "Test", body: "Body", url: "/menu")
      }.to change(NotificationDelivery, :count).by(1)

      delivery = NotificationDelivery.last
      expect(delivery.title).to eq("Test")
      expect(delivery.body).to eq("Body")
      expect(delivery.url).to eq("/menu")
      expect(delivery.sent_count).to eq(2)
      expect(delivery.pruned_count).to eq(0)
      expect(delivery.fired_at).to be_within(2.seconds).of(Time.current)
    end

    it "prunes subscriptions whose endpoint has expired (410)" do
      response = double("HTTP response", code: "410", body: "Gone", inspect: "<410>")
      expect(WebPush).to receive(:payload_send).with(hash_including(endpoint: sub_a.endpoint))
                                               .and_raise(WebPush::ExpiredSubscription.new(response, "fcm.example"))
      expect(WebPush).to receive(:payload_send).with(hash_including(endpoint: sub_b.endpoint))
                                               .and_return(true)

      result = described_class.broadcast(title: "x", body: "y")

      expect(result).to eq(sent: 1, pruned: 1)
      expect(PushSubscription.exists?(sub_a.id)).to be false
    end

    it "prunes subscriptions the push service marks invalid (404)" do
      response = double("HTTP response", code: "404", body: "Not Found", inspect: "<404>")
      expect(WebPush).to receive(:payload_send).and_raise(WebPush::InvalidSubscription.new(response, "fcm.example")).at_least(:once)

      result = described_class.broadcast(title: "x", body: "y")

      expect(result).to eq(sent: 0, pruned: 2)
      expect(PushSubscription.count).to eq(0)
    end

    it "lets unexpected ResponseErrors bubble up" do
      response = double("HTTP response", code: "500", body: "Internal", inspect: "<500>")
      expect(WebPush).to receive(:payload_send).and_raise(WebPush::ResponseError.new(response, "fcm.example"))

      expect {
        described_class.broadcast(title: "x", body: "y")
      }.to raise_error(WebPush::ResponseError)
    end

    it "raises NotConfiguredError when keys aren't set" do
      ENV.delete("VAPID_PUBLIC_KEY")
      ENV.delete("VAPID_PRIVATE_KEY")
      expect {
        described_class.broadcast(title: "x", body: "y")
      }.to raise_error(PushNotifier::NotConfiguredError)
    end

    it "only notifies the recipient's subscriptions, not other users'" do
      user_a = create(:user)
      user_b = create(:user)
      create(:push_subscription, user: user_a, endpoint: "https://push.example/A")
      create(:push_subscription, user: user_b, endpoint: "https://push.example/B")

      ENV["VAPID_PUBLIC_KEY"]  = "PUB"
      ENV["VAPID_PRIVATE_KEY"] = "PRV"

      expect(WebPush).to receive(:payload_send)
        .with(hash_including(endpoint: "https://push.example/A")).once.and_return(true)
      expect(WebPush).not_to receive(:payload_send)
        .with(hash_including(endpoint: "https://push.example/B"))

      described_class.broadcast(title: "Hi", body: "Msg", user: user_a)
    end
  end
end
