require "rails_helper"

RSpec.describe "GET /api/v1/today", type: :request do
  let(:token) { "test-token-123" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("API_TOKEN").and_return(token)
    seed_minimum_data
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
    get "/api/v1/today", headers: { "Authorization" => "Bearer #{token}" }

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

  def seed_minimum_data
    Plan.find_or_create_by!(slug: "active") do |p|
      p.name = "Active day"
      p.target_kcal = 2075
      p.target_protein_g = 180
      p.target_carbs_g = 180
      p.target_fat_g = 80
    end
  end
end
