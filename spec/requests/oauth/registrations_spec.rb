require "rails_helper"

RSpec.describe "POST /oauth/register (Dynamic Client Registration)", type: :request do
  it "registers a public claude.ai client and returns client_id with token_endpoint_auth_method=none" do
    expect {
      post "/oauth/register",
           params: { client_name: "Claude", redirect_uris: [ "https://claude.ai/api/mcp/auth_callback/x" ] }.to_json,
           headers: { "Content-Type" => "application/json" }
    }.to change(Doorkeeper::Application, :count).by(1)

    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body["client_id"]).to be_present
    expect(body["token_endpoint_auth_method"]).to eq("none")
    expect(body).not_to have_key("client_secret")
    expect(body["grant_types"]).to include("authorization_code", "refresh_token")
    expect(body["scope"]).to eq("mcp")
    expect(body["redirect_uris"]).to eq([ "https://claude.ai/api/mcp/auth_callback/x" ])

    app = Doorkeeper::Application.find_by(uid: body["client_id"])
    expect(app.confidential).to be(false)
    expect(app.scopes.to_s).to eq("mcp")
  end

  it "rejects redirect_uris missing entirely" do
    post "/oauth/register",
         params: { client_name: "Claude" }.to_json,
         headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to eq("invalid_redirect_uri")
  end

  it "rejects redirect_uris not on claude.ai or claude.com (anti-phishing whitelist)" do
    post "/oauth/register",
         params: { client_name: "Claude", redirect_uris: [ "https://attacker.example/cb" ] }.to_json,
         headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to eq("invalid_redirect_uri")
    expect(Doorkeeper::Application.count).to eq(0)
  end

  it "rejects http (non-https) redirect URIs even on the whitelist hosts" do
    post "/oauth/register",
         params: { client_name: "Claude", redirect_uris: [ "http://claude.ai/cb" ] }.to_json,
         headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
  end

  it "rejects mixed lists where any one URI is off-whitelist" do
    post "/oauth/register",
         params: { client_name: "Claude",
                   redirect_uris: [ "https://claude.ai/cb", "https://attacker.example/cb" ] }.to_json,
         headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
    expect(Doorkeeper::Application.count).to eq(0)
  end
end
