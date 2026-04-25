require "rails_helper"

RSpec.describe "GET /api/v1/plans", type: :request do
  before do
    stub_api_token
    seed_plan(slug: "exercise")
    seed_plan(slug: "active")
    seed_plan(slug: "rest")
  end

  it "returns plans in canonical order with targets" do
    get "/api/v1/plans", headers: auth_headers
    expect(response).to have_http_status(:ok)
    plans = response.parsed_body["plans"]
    expect(plans.map { |p| p["slug"] }).to eq(%w[exercise active rest])
    expect(plans.first).to include("target_kcal", "target_protein_g", "target_carbs_g", "target_fat_g")
  end
end
