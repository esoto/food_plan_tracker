require "rails_helper"

RSpec.describe PushSubscriptionsController, type: :request do
  let(:body) do
    {
      endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
      keys: { p256dh: "p256dh-key", auth: "auth-secret" }
    }
  end

  before { sign_in_as }

  describe "POST /push_subscriptions" do
    it "stores a new subscription and returns 201" do
      expect {
        post "/push_subscriptions", params: body.to_json,
                                    headers: { "Content-Type" => "application/json" }
      }.to change(PushSubscription, :count).by(1)

      expect(response).to have_http_status(:created)

      sub = PushSubscription.last
      expect(sub.endpoint).to eq(body[:endpoint])
      expect(sub.p256dh_key).to eq("p256dh-key")
      expect(sub.auth_key).to eq("auth-secret")
    end

    it "is idempotent — re-subscribing the same endpoint updates rather than duplicating" do
      post "/push_subscriptions", params: body.to_json,
                                  headers: { "Content-Type" => "application/json" }
      original = PushSubscription.last

      expect {
        post "/push_subscriptions",
             params: body.merge(keys: { p256dh: "rotated", auth: "rotated-auth" }).to_json,
             headers: { "Content-Type" => "application/json" }
      }.not_to change(PushSubscription, :count)

      expect(original.reload.p256dh_key).to eq("rotated")
    end

    it "rejects a payload missing the keys hash with 400 and writes nothing" do
      expect {
        post "/push_subscriptions",
             params: { endpoint: body[:endpoint] }.to_json,
             headers: { "Content-Type" => "application/json" }
      }.not_to change(PushSubscription, :count)

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /push_subscriptions" do
    it "removes the subscription matching the given endpoint" do
      PushSubscription.create!(endpoint: body[:endpoint], p256dh_key: "x", auth_key: "y")

      expect {
        delete "/push_subscriptions",
               params: { endpoint: body[:endpoint] }.to_json,
               headers: { "Content-Type" => "application/json" }
      }.to change(PushSubscription, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "is a no-op for an unknown endpoint" do
      expect {
        delete "/push_subscriptions",
               params: { endpoint: "https://example.com/unknown" }.to_json,
               headers: { "Content-Type" => "application/json" }
      }.not_to change(PushSubscription, :count)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /push_subscriptions/test" do
    it "returns 503 when VAPID keys are missing" do
      allow(PushNotifier).to receive(:configured?).and_return(false)

      post "/push_subscriptions/test"
      expect(response).to have_http_status(:service_unavailable)
    end

    it "broadcasts and redirects with a flash count when configured" do
      allow(PushNotifier).to receive(:configured?).and_return(true)
      allow(PushNotifier).to receive(:broadcast).and_return(sent: 2, pruned: 0)

      post "/push_subscriptions/test"

      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to match(/2 delivered/)
    end
  end
end
