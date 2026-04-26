require "rails_helper"

RSpec.describe PushNotifier do
  describe ".configured?" do
    it "is false when either env var is missing" do
      ClimateControl.modify(VAPID_PUBLIC_KEY: nil, VAPID_PRIVATE_KEY: nil) do
        expect(described_class.configured?).to be false
      end if defined?(ClimateControl)

      stub_const("ENV", ENV.to_h.except("VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY"))
      expect(described_class.configured?).to be false
    end
  end

  describe ".broadcast" do
    let!(:sub_a) { PushSubscription.create!(endpoint: "https://fcm.example/A", p256dh_key: "p", auth_key: "a") }
    let!(:sub_b) { PushSubscription.create!(endpoint: "https://fcm.example/B", p256dh_key: "p", auth_key: "a") }

    before do
      stub_const("ENV", ENV.to_h.merge(
        "VAPID_PUBLIC_KEY"  => "PUB",
        "VAPID_PRIVATE_KEY" => "PRV"
      ))
    end

    it "calls WebPush.payload_send for each subscription" do
      expect(WebPush).to receive(:payload_send).twice.and_return(true)

      result = described_class.broadcast(title: "Hi", body: "World", url: "/menu")
      expect(result).to eq(sent: 2, pruned: 0)
    end

    it "prunes subscriptions whose endpoint has expired (410)" do
      response = double("HTTP response", code: "410", body: "Gone", inspect: "<410>")
      expect(WebPush).to receive(:payload_send).with(hash_including(endpoint: sub_a.endpoint))
                                               .and_raise(WebPush::ResponseError.new(response, "fcm.example"))
      expect(WebPush).to receive(:payload_send).with(hash_including(endpoint: sub_b.endpoint))
                                               .and_return(true)

      result = described_class.broadcast(title: "x", body: "y")

      expect(result).to eq(sent: 1, pruned: 1)
      expect(PushSubscription.exists?(sub_a.id)).to be false
    end

    it "raises NotConfiguredError when keys aren't set" do
      stub_const("ENV", ENV.to_h.except("VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY"))
      expect {
        described_class.broadcast(title: "x", body: "y")
      }.to raise_error(PushNotifier::NotConfiguredError)
    end
  end
end
