require "rails_helper"

RSpec.describe PushSubscriptionsController, type: :request do
  let(:user) { create(:user, password: "password") }
  let(:body) do
    {
      endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
      keys: { p256dh: "p256dh-key", auth: "auth-secret" }
    }
  end

  before do
    sign_in_as(user)
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
  end

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
      PushSubscription.create!(endpoint: body[:endpoint], p256dh_key: "x", auth_key: "y", user: user)

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

  describe "cross-tenant isolation" do
    it "POST does not take over another user's subscription by endpoint" do
      other = create(:user)
      shared = "https://push.example/shared"
      PushSubscription.create!(endpoint: shared, p256dh_key: "orig", auth_key: "orig", user: other)

      # The signed-in user posts the same endpoint. With scoping, the controller
      # does not find the other user's record; it initialises a new one and hits
      # the DB unique constraint rather than overwriting the existing record.
      post "/push_subscriptions",
           params: { endpoint: shared, keys: { p256dh: "new", auth: "new" } }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:conflict)
      # Regardless of the response status, the other user's keys must be intact.
      expect(PushSubscription.find_by(endpoint: shared, user: other).p256dh_key).to eq("orig")
    end

    it "DELETE does not destroy another user's subscription" do
      other = create(:user)
      sub = PushSubscription.create!(endpoint: "https://push.example/victim",
                                     p256dh_key: "x", auth_key: "y", user: other)

      delete "/push_subscriptions",
             params: { endpoint: sub.endpoint }.to_json,
             headers: { "Content-Type" => "application/json" }

      expect(PushSubscription.exists?(sub.id)).to be true
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
