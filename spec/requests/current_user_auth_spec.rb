require "rails_helper"

RSpec.describe "Current.user auth wiring", type: :request do
  describe "web session cookie auth" do
    let!(:user) { User.create!(email_address: "test@example.com", password: "correcthorsebatterystaple") }

    it "sets Current.session on successful login" do
      expect(Current).to receive(:session=).and_call_original
      post session_path, params: { email_address: user.email_address, password: "correcthorsebatterystaple" }
      expect(response).to redirect_to(root_path)
    end

    it "makes Current.user available on subsequent requests" do
      post session_path, params: { email_address: user.email_address, password: "correcthorsebatterystaple" }

      get settings_path
      expect(response.body).to include(user.email_address)
    end
  end

  describe "API Bearer token auth" do
    it "sets Current.user from the authenticated token" do
      token = stub_api_token
      user  = token.user

      expect(Current).to receive(:user=).with(user).and_call_original

      get "/api/v1/goals", headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "MCP OAuth token auth" do
    let(:user)        { create(:user) }
    let(:application) { Doorkeeper::Application.create!(name: "Test Client", redirect_uri: "https://example.com/cb", scopes: "mcp", confidential: true) }
    let!(:token)      { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "mcp") }

    it "sets Current.user from the Doorkeeper token" do
      expect(Current).to receive(:user=).with(user).and_call_original

      post "/mcp",
           params: { jsonrpc: "2.0", id: 1, method: "initialize" }.to_json,
           headers: { "Authorization" => "Bearer #{token.plaintext_token}", "Content-Type" => "application/json" }
      expect(response).to have_http_status(:ok)
    end
  end
end
