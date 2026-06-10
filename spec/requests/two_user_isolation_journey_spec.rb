# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Two-user isolation journey', type: :request do
  let(:alice_email) { 'alice@example.com' }
  let(:alice_password) { 'alicepassword12345' }
  let(:bob_email) { 'bob@example.com' }
  let(:bob_password) { 'bobpassword12345' }

  def register_user(email, password)
    post '/registration', params: {
      user: {
        email_address: email,
        password: password,
        password_confirmation: password
      }
    }
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response).to have_http_status(:ok)
    User.find_by!(email_address: email)
  end

  def mcp_rpc(method, params = nil, token:)
    body = { jsonrpc: '2.0', id: 1, method: method }
    body[:params] = params if params
    post '/mcp', params: body.to_json, headers: {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
    JSON.parse(response.body)
  end

  before do
    @alice = register_user(alice_email, alice_password)
    @bob = register_user(bob_email, bob_password)

    post '/session', params: { email_address: alice_email, password: alice_password }
    expect(response).to redirect_to(root_path)
    follow_redirect!
    Current.user = @alice
  end

  it 'Phase 1: Alice creates a supplement, Bob signs in and does not see it' do
    post settings_supplements_url, params: {
      supplement: {
        name: 'VitaminD',
        dose: '1000 IU',
        critical: false,
        notes: 'Daily'
      }
    }

    alice_supp = Supplement.find_by!(name: 'VitaminD', user: @alice)
    expect(alice_supp.user_id).to eq(@alice.id)

    get settings_supplements_url
    expect(response.body).to include('VitaminD')

    post '/session', params: { email_address: bob_email, password: bob_password }
    expect(response).to redirect_to(root_path)
    follow_redirect!
    Current.user = @bob

    get settings_supplements_url
    expect(response.body).not_to include('VitaminD')
  end

  it 'Phase 2: API V1 isolation — Alice and Bob see only their own supplements' do
    alice_token = ApiToken.create!(user: @alice, name: 'alice-token', token: 'alice-test-123')
    bob_token = ApiToken.create!(user: @bob, name: 'bob-token', token: 'bob-test-123')

    alice_headers = { 'Authorization' => 'Bearer alice-test-123', 'Content-Type' => 'application/json' }
    bob_headers = { 'Authorization' => 'Bearer bob-test-123', 'Content-Type' => 'application/json' }

    alice_supp = create(:supplement, user: @alice, name: 'AliceSupp')
    bob_supp = create(:supplement, user: @bob, name: 'BobSupp')

    get '/api/v1/supplements', headers: alice_headers
    expect(response).to have_http_status(:ok)
    alice_result = JSON.parse(response.body)
    alice_names = alice_result['supplements'].map { |s| s['name'] }
    expect(alice_names).to include('AliceSupp')
    expect(alice_names).not_to include('BobSupp')

    get '/api/v1/supplements', headers: bob_headers
    expect(response).to have_http_status(:ok)
    bob_result = JSON.parse(response.body)
    bob_names = bob_result['supplements'].map { |s| s['name'] }
    expect(bob_names).to include('BobSupp')
    expect(bob_names).not_to include('AliceSupp')
  end

  it 'Phase 2: API V1 — Bob cannot patch Alice\'s plan' do
    alice_plan = create(:plan, user: @alice, slug: 'alice-plan')
    bob_token = ApiToken.create!(user: @bob, name: 'bob-token', token: 'bob-test-123')
    bob_headers = { 'Authorization' => 'Bearer bob-test-123', 'Content-Type' => 'application/json' }

    patch "/api/v1/plans/#{alice_plan.id}", params: {
      plan: { target_kcal: 3000 }
    }.to_json, headers: bob_headers

    expect(response).to have_http_status(:not_found)
    expect(alice_plan.reload.target_kcal).not_to eq(3000)
  end

  it 'Phase 3: MCP isolation — Alice and Bob see only their own supplements' do
    app = Doorkeeper::Application.create!(
      name: 'Claude MCP Test',
      redirect_uri: 'https://example.com/cb',
      scopes: 'mcp',
      confidential: true
    )
    alice_mcp_token = Doorkeeper::AccessToken.create!(
      application: app,
      resource_owner_id: @alice.id,
      scopes: 'mcp'
    )
    bob_mcp_token = Doorkeeper::AccessToken.create!(
      application: app,
      resource_owner_id: @bob.id,
      scopes: 'mcp'
    )

    create(:supplement, user: @alice, name: 'AliceMCPSupp')
    create(:supplement, user: @bob, name: 'BobMCPSupp')

    alice_result = mcp_rpc('tools/call', {
      name: 'list_supplements',
      arguments: {}
    }, token: alice_mcp_token.plaintext_token)

    alice_text = JSON.parse(alice_result['result']['content'].first['text'])
    alice_names = alice_text['supplements'].map { |s| s['name'] }
    expect(alice_names).to include('AliceMCPSupp')
    expect(alice_names).not_to include('BobMCPSupp')

    bob_result = mcp_rpc('tools/call', {
      name: 'list_supplements',
      arguments: {}
    }, token: bob_mcp_token.plaintext_token)

    bob_text = JSON.parse(bob_result['result']['content'].first['text'])
    bob_names = bob_text['supplements'].map { |s| s['name'] }
    expect(bob_names).to include('BobMCPSupp')
    expect(bob_names).not_to include('AliceMCPSupp')
  end

  it 'Phase 4: Three-surface proof — Alice sees her supplement on HTML, API, and MCP while Bob cannot' do
    create(:supplement, user: @alice, name: 'AliceProofSupp')
    create(:supplement, user: @bob, name: 'BobProofSupp')

    alice_token = ApiToken.create!(user: @alice, name: 'alice-token', token: 'alice-test-123')
    bob_token = ApiToken.create!(user: @bob, name: 'bob-token', token: 'bob-test-123')
    alice_headers = { 'Authorization' => 'Bearer alice-test-123', 'Content-Type' => 'application/json' }
    bob_headers = { 'Authorization' => 'Bearer bob-test-123', 'Content-Type' => 'application/json' }

    app = Doorkeeper::Application.create!(
      name: 'Claude MCP Test 2',
      redirect_uri: 'https://example.com/cb',
      scopes: 'mcp',
      confidential: true
    )
    alice_mcp_token = Doorkeeper::AccessToken.create!(
      application: app,
      resource_owner_id: @alice.id,
      scopes: 'mcp'
    )
    bob_mcp_token = Doorkeeper::AccessToken.create!(
      application: app,
      resource_owner_id: @bob.id,
      scopes: 'mcp'
    )

    post '/session', params: { email_address: alice_email, password: alice_password }
    follow_redirect!
    Current.user = @alice

    get settings_supplements_url
    expect(response.body).to include('AliceProofSupp')
    expect(response.body).not_to include('BobProofSupp')

    post '/session', params: { email_address: bob_email, password: bob_password }
    follow_redirect!
    Current.user = @bob

    get settings_supplements_url
    expect(response.body).to include('BobProofSupp')
    expect(response.body).not_to include('AliceProofSupp')

    get '/api/v1/supplements', headers: alice_headers
    alice_api = JSON.parse(response.body)
    alice_api_names = alice_api['supplements'].map { |s| s['name'] }
    expect(alice_api_names).to include('AliceProofSupp')
    expect(alice_api_names).not_to include('BobProofSupp')

    get '/api/v1/supplements', headers: bob_headers
    bob_api = JSON.parse(response.body)
    bob_api_names = bob_api['supplements'].map { |s| s['name'] }
    expect(bob_api_names).to include('BobProofSupp')
    expect(bob_api_names).not_to include('AliceProofSupp')

    alice_mcp_result = mcp_rpc('tools/call', {
      name: 'list_supplements',
      arguments: {}
    }, token: alice_mcp_token.plaintext_token)

    alice_mcp_text = JSON.parse(alice_mcp_result['result']['content'].first['text'])
    alice_mcp_names = alice_mcp_text['supplements'].map { |s| s['name'] }
    expect(alice_mcp_names).to include('AliceProofSupp')
    expect(alice_mcp_names).not_to include('BobProofSupp')

    bob_mcp_result = mcp_rpc('tools/call', {
      name: 'list_supplements',
      arguments: {}
    }, token: bob_mcp_token.plaintext_token)

    bob_mcp_text = JSON.parse(bob_mcp_result['result']['content'].first['text'])
    bob_mcp_names = bob_mcp_text['supplements'].map { |s| s['name'] }
    expect(bob_mcp_names).to include('BobProofSupp')
    expect(bob_mcp_names).not_to include('AliceProofSupp')
  end

  it 'unauthenticated GET /api/v1/plans returns 401' do
    get '/api/v1/plans', headers: { 'Content-Type' => 'application/json' }
    expect(response).to have_http_status(:unauthorized)
  end
end
