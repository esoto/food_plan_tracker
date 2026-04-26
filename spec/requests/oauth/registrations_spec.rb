require "rails_helper"

RSpec.describe "POST /oauth/register (Dynamic Client Registration)", type: :request do
  it "creates a Doorkeeper application and returns plaintext client_id/secret" do
    expect {
      post "/oauth/register",
           params: { client_name: "Claude", redirect_uris: [ "https://claude.ai/api/mcp/auth_callback/x" ] }.to_json,
           headers: { "Content-Type" => "application/json" }
    }.to change(Doorkeeper::Application, :count).by(1)

    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body["client_id"]).to be_present
    expect(body["client_secret"]).to be_present
    expect(body["grant_types"]).to include("authorization_code", "refresh_token")
    expect(body["scope"]).to eq("mcp")
    expect(body["redirect_uris"]).to eq([ "https://claude.ai/api/mcp/auth_callback/x" ])
  end

  it "rejects registrations missing redirect_uris" do
    post "/oauth/register",
         params: { client_name: "Claude" }.to_json,
         headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to eq("invalid_redirect_uri")
  end
end
