require "rails_helper"

RSpec.describe "GET /api/v1/today", type: :request do
  before do
    stub_api_token
    seed_plan(slug: "active")
  end

  it_behaves_like "food-gated endpoint" do
    let(:make_request) { -> { get "/api/v1/today", headers: auth_headers } }
  end

  it "returns 401 without a token" do
    get "/api/v1/today"
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq("error" => "unauthorized")
  end

  it "returns 401 with a wrong token" do
    get "/api/v1/today", headers: { "Authorization" => "Bearer wrong" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns today snapshot with valid token" do
    get "/api/v1/today", headers: auth_headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["date"]).to eq(Date.current.iso8601)
    expect(body["plan"]).to include("slug")
    expect(body["targets"]).to include("kcal", "protein_g", "carbs_g", "fat_g")
    expect(body["consumed"]).to include("kcal", "protein_g", "carbs_g", "fat_g")
    expect(body).to have_key("weight_kg")
    expect(body["completed_meal_ids"]).to be_an(Array)
    expect(body["logged_foods"]).to be_an(Array)
  end
end
