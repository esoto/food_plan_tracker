require "rails_helper"

RSpec.describe "Api::V1::FoodsController", type: :request do
  before do
    stub_api_token
    seed_food(name: "Chicken breast")
    seed_food(name: "Salmon", category: "fat", kcal: 208, protein_g: 20, carbs_g: 0, fat_g: 13)
    seed_food(name: "Banana", category: "carb", serving_grams: 118, kcal: 105, protein_g: 1.3, carbs_g: 27, fat_g: 0.4)
  end

  describe "GET /api/v1/foods" do
    it "lists foods alphabetically" do
      get "/api/v1/foods", headers: auth_headers
      expect(response).to have_http_status(:ok)
      names = response.parsed_body["foods"].map { |f| f["name"] }
      expect(names).to eq(names.sort)
    end

    it "filters by query (case-insensitive)" do
      get "/api/v1/foods?q=CHICK", headers: auth_headers
      expect(response.parsed_body["foods"].map { |f| f["name"] }).to eq([ "Chicken breast" ])
    end
  end

  describe "POST /api/v1/foods" do
    let(:valid_payload) do
      {
        food: {
          name: "Greek yogurt 5%",
          category: "protein",
          serving_grams: 100,
          kcal: 95,
          protein_g: 10,
          carbs_g: 4,
          fat_g: 5,
          notes: "plain"
        }
      }
    end

    it "creates a food and returns it serialized" do
      expect {
        post "/api/v1/foods", params: valid_payload.to_json, headers: auth_headers
      }.to change(Food, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["food"]
      expect(body).to include("id", "name" => "Greek yogurt 5%", "category" => "protein", "kcal" => 95)
    end

    it "returns 422 with the validation message on invalid params" do
      bad = valid_payload.deep_merge(food: { name: "" })
      post "/api/v1/foods", params: bad.to_json, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to match(/Name can't be blank/)
    end

    it "returns 401 without a token" do
      post "/api/v1/foods", params: valid_payload.to_json,
                            headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
