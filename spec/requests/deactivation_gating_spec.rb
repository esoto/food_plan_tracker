require "rails_helper"

# Every authenticated surface must fail closed for a deactivated user:
# the web session cookie, the /api/v1 bearer token, and the /mcp OAuth
# access token. Each example goes RED if its specific gate line is reverted.
RSpec.describe "Deactivation gating", type: :request do
  describe "web session cookie" do
    it "tears down the resumed session and redirects to login once the user is deactivated" do
      user = create(:user)
      sign_in_as(user)
      expect(Session.where(user: user).count).to eq(1)

      # update! (not deactivate!) so the session is NOT destroyed by the model
      # callback — we are exercising the cookie gate itself, not deactivate!.
      user.update!(deactivated_at: Time.current)

      get root_path
      expect(response).to redirect_to(new_session_path)
      expect(Session.where(user: user).count).to eq(0)

      # And the torn-down session is not silently recreated on the next hit.
      get root_path
      expect(response).to redirect_to(new_session_path)
      expect(Session.where(user: user).count).to eq(0)
    end
  end

  describe "/api/v1 bearer token" do
    let(:user)      { create(:user) }
    let!(:token)    { user.api_tokens.create!(name: "spec") }
    let(:plaintext) { token.token }

    it "returns a 401 byte-identical to the invalid-token 401 and never touches last_used_at" do
      seed_plan(slug: "active", user: user)

      get "/api/v1/today", headers: { "Authorization" => "Bearer definitely-not-valid" }
      invalid_status = response.status
      invalid_body   = response.parsed_body

      user.update!(deactivated_at: Time.current)

      get "/api/v1/today", headers: { "Authorization" => "Bearer #{plaintext}" }

      expect(response.status).to eq(invalid_status)
      expect(response.parsed_body).to eq(invalid_body)
      expect(token.reload.last_used_at).to be_nil
    end

    it "restores access after reactivation" do
      seed_plan(slug: "active", user: user)
      user.deactivate!
      user.reactivate!

      get "/api/v1/today", headers: { "Authorization" => "Bearer #{plaintext}" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "/mcp OAuth access token" do
    let(:user)        { create(:user) }
    let(:application) { Doorkeeper::Application.create!(name: "Test Client", redirect_uri: "https://example.com/cb", scopes: "mcp", confidential: true) }
    let!(:token)      { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "mcp") }

    def post_tools_list(access_token)
      post "/mcp",
           params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
           headers: { "Authorization" => "Bearer #{access_token}", "Content-Type" => "application/json" }
    end

    it "returns 401 for a deactivated owner" do
      user.update!(deactivated_at: Time.current)

      post_tools_list(token.plaintext_token)
      expect(response).to have_http_status(:unauthorized)
    end

    it "renders a 401 (not a 200 internal_error) when the resource owner cannot be resolved" do
      # A live token whose owner lookup yields nil used to leave Current.user
      # nil and 500 inside a tool handler. A truly dangling resource_owner_id
      # is unreachable now (FK oauth_access_tokens.resource_owner_id → users.id),
      # so we force the nil resolution directly to lock the fail-closed branch.
      allow(User).to receive(:active).and_return(User.none)

      post_tools_list(token.plaintext_token)

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "message")).to eq("unauthorized")
      expect(response.parsed_body.dig("error", "message")).not_to eq("internal_error")
    end

    it "restores access after reactivation" do
      Current.user = user
      seed_plan(slug: "active", user: user)
      user.deactivate!
      user.reactivate!

      post_tools_list(token.plaintext_token)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "OAuth authorization grant" do
    let(:user)        { create(:user) }
    let(:application) { Doorkeeper::Application.create!(name: "Claude", redirect_uri: "https://claude.ai/api/mcp/auth_callback", scopes: "mcp", confidential: false) }
    let(:authorize_params) do
      {
        response_type:         "code",
        client_id:             application.uid,
        redirect_uri:          "https://claude.ai/api/mcp/auth_callback",
        scope:                 "mcp",
        code_challenge:        "x" * 43,
        code_challenge_method: "S256",
        state:                 SecureRandom.hex(16)
      }
    end

    it "a deactivated user's live cookie cannot start a new authorization grant" do
      sign_in_as(user)
      user.update!(deactivated_at: Time.current)

      get "/oauth/authorize", params: authorize_params
      expect(response).to redirect_to(new_session_path)
    end
  end
end
