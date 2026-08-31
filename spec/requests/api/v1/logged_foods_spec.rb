require "rails_helper"

RSpec.describe "Api::V1::LoggedFoodsController", type: :request do
  let(:plan) { seed_plan(slug: "active") }
  let(:food) { seed_food(name: "Chicken breast") }

  before { stub_api_token; plan; food }

  it_behaves_like "food-gated endpoint" do
    let(:make_request) { -> { post "/api/v1/foods/#{food.id}/log", params: {}.to_json, headers: auth_headers } }
  end

  it "logs a food (default quantity = serving_grams) and reports updated macros" do
    post "/api/v1/foods/#{food.id}/log", params: {}.to_json, headers: auth_headers
    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body["day"]["logged_foods"].first["food_name"]).to eq("Chicken breast")
    expect(body["day"]["consumed"]["kcal"]).to eq(food.kcal)
  end

  it "honors quantity_grams override" do
    post "/api/v1/foods/#{food.id}/log", params: { quantity_grams: 200 }.to_json, headers: auth_headers
    expect(response.parsed_body["day"]["logged_foods"].first["quantity_grams"]).to eq(200.0)
  end

  it "deletes a logged food" do
    entry = DailyLog.today.logged_foods.create!(food: food, quantity_grams: 100, logged_at: Time.current)
    delete "/api/v1/logged_foods/#{entry.id}", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect { entry.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }

    it "DELETE another user's logged_food returns 404 and does not destroy it" do
      b_plan = create(:plan, user: user_b)
      b_log  = create(:daily_log, user: user_b, plan: b_plan)
      b_food = create(:logged_food, daily_log: b_log, user: user_b)
      delete "/api/v1/logged_foods/#{b_food.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
      expect(LoggedFood.exists?(b_food.id)).to be(true)
    end
  end
end
