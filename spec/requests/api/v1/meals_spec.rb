require "rails_helper"

RSpec.describe "GET /api/v1/meals", type: :request do
  before do
    stub_api_token
    plan = seed_plan(slug: "active")
    plan.meals.find_or_create_by!(name: "Breakfast") do |m|
      m.scheduled_time = Time.utc(2000, 1, 1, 7, 0)
      m.position = 1
      m.target_kcal = 400
      m.target_protein_g = 30
      m.target_carbs_g = 50
      m.target_fat_g = 10
    end
  end

  it "returns meals for the requested plan" do
    get "/api/v1/meals?plan=active", headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["plan"]["slug"]).to eq("active")
    expect(body["meals"].first["name"]).to eq("Breakfast")
    expect(body["meals"].first).to have_key("time_of_day")
  end

  it "returns 404 for an unknown plan slug" do
    get "/api/v1/meals?plan=missing", headers: auth_headers
    expect(response).to have_http_status(:not_found)
  end
end
