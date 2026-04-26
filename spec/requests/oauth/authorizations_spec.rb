require "rails_helper"

# Regression coverage for the post-login loop in PR #16: Doorkeeper's
# AuthorizationsController inherits from Doorkeeper::ApplicationController
# (which extends ActionController::Base directly), so our Authentication
# concern's `before_action :require_authentication` never runs on the
# authorize endpoint. The resource_owner_authenticator block must resume
# the session itself or Current.user is always nil — and the user gets
# bounced back to /session/new immediately after signing in.
RSpec.describe "GET /oauth/authorize", type: :request do
  let(:user)        { create(:user) }
  let(:session)     { user.sessions.create!(user_agent: "rspec", ip_address: "127.0.0.1") }
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

  it "redirects unauthenticated callers to the login page" do
    get "/oauth/authorize", params: authorize_params
    expect(response).to redirect_to(new_session_path)
  end

  it "renders the styled consent screen for callers who just signed in" do
    user.update!(password: "secret-pw-123")
    post "/session", params: { email_address: user.email_address, password: "secret-pw-123" }
    expect(response).to have_http_status(:redirect) # follows root_url after login

    get "/oauth/authorize", params: authorize_params

    expect(response).to have_http_status(:ok)
    expect(response).not_to redirect_to(new_session_path)
    # Custom view picked up + scope label from oauth.en.yml (would be "Mcp" if locale missing)
    expect(response.body).to include("Authorize Claude")
    expect(response.body).to include("Read and write your food log")

    # Both forms must round-trip every PKCE/state field. Dropping one would
    # break the OAuth callback silently (Doorkeeper rejects with a generic
    # error) so we lock the contract at the rendered HTML.
    %w[client_id redirect_uri state response_type scope code_challenge code_challenge_method].each do |field|
      expect(response.body).to include(%(name="#{field}")),
                              "expected hidden form field `#{field}` in the consent HTML"
    end

    # Both authorize (POST) and deny (DELETE) forms must be present.
    expect(response.body).to include(I18n.t("doorkeeper.authorizations.buttons.authorize"))
    expect(response.body).to include(I18n.t("doorkeeper.authorizations.buttons.deny"))
    expect(response.body).to match(%r{<input[^>]+name="_method"[^>]+value="delete"}i)
  end
end
