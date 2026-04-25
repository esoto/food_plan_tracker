require "rails_helper"

RSpec.describe "GET /api/v1/foods", type: :request do
  before do
    stub_api_token
    seed_food(name: "Chicken breast")
    seed_food(name: "Salmon", category: "fat", kcal: 208, protein_g: 20, carbs_g: 0, fat_g: 13)
    seed_food(name: "Banana", category: "carb", serving_grams: 118, kcal: 105, protein_g: 1.3, carbs_g: 27, fat_g: 0.4)
  end

  it "lists foods alphabetically" do
    get "/api/v1/foods", headers: auth_headers
    expect(response).to have_http_status(:ok)
    names = response.parsed_body["foods"].map { |f| f["name"] }
    expect(names).to eq(names.sort)
  end

  it "filters by query (case-insensitive)" do
    get "/api/v1/foods?q=CHICK", headers: auth_headers
    expect(response.parsed_body["foods"].map { |f| f["name"] }).to eq(["Chicken breast"])
  end
end
