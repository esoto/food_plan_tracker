require "rails_helper"

RSpec.describe "Well-known discovery endpoints", type: :request do
  describe "GET /.well-known/oauth-authorization-server" do
    it "advertises the OAuth endpoints claude.ai needs to register and exchange tokens" do
      get "/.well-known/oauth-authorization-server"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["issuer"]).to be_present
      expect(body["authorization_endpoint"]).to end_with("/oauth/authorize")
      expect(body["token_endpoint"]).to end_with("/oauth/token")
      expect(body["registration_endpoint"]).to end_with("/oauth/register")
      expect(body["grant_types_supported"]).to include("authorization_code", "refresh_token")
      expect(body["code_challenge_methods_supported"]).to include("S256")
      expect(body["scopes_supported"]).to include("mcp")
    end
  end

  describe "GET /.well-known/oauth-protected-resource" do
    it "points the connector at the MCP endpoint and the auth server protecting it" do
      get "/.well-known/oauth-protected-resource"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["resource"]).to end_with("/mcp")
      expect(body["authorization_servers"]).to be_an(Array).and(be_present)
      expect(body["scopes_supported"]).to include("mcp")
    end
  end
end
