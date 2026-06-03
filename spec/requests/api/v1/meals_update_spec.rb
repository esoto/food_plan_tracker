require "rails_helper"

RSpec.describe "Api::V1::MealsController#update", type: :request do
  before { stub_api_token }

  let(:plan) { create(:plan, user: Current.user) }
  let(:meal) do
    create(:meal, plan: plan, user: Current.user, name: "Breakfast",
           target_kcal: 500, target_protein_g: 40, target_carbs_g: 50, target_fat_g: 18,
           scheduled_time: Time.utc(2000, 1, 1, 7, 0))
  end

  describe "PATCH /api/v1/meals/:id" do
    it "updates name, scheduled_time (HH:MM), and macros" do
      patch "/api/v1/meals/#{meal.id}",
            params: { meal: { name: "Pre-workout", scheduled_time: "06:30", target_kcal: 600 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["meal"]
      expect(body["name"]).to eq("Pre-workout")
      expect(body["target_kcal"]).to eq(600)

      meal.reload
      expect(meal.name).to eq("Pre-workout")
      expect(meal.target_kcal).to eq(600)
      expect(meal.scheduled_time.utc.strftime("%H:%M")).to eq("06:30")
    end

    it "leaves scheduled_time unchanged when omitted" do
      patch "/api/v1/meals/#{meal.id}",
            params: { meal: { target_kcal: 550 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(meal.reload.target_kcal).to eq(550)
      expect(meal.scheduled_time.utc.strftime("%H:%M")).to eq("07:00")
    end

    it "rejects out-of-range scheduled_time (25:00) with 422" do
      patch "/api/v1/meals/#{meal.id}",
            params: { meal: { scheduled_time: "25:00" } }.to_json,
            headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects out-of-range scheduled_time (12:60) with 422" do
      patch "/api/v1/meals/#{meal.id}",
            params: { meal: { scheduled_time: "12:60" } }.to_json,
            headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "400s when the :meal key is omitted from the body" do
      patch "/api/v1/meals/#{meal.id}", params: {}.to_json, headers: auth_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects malformed scheduled_time strings with 422" do
      patch "/api/v1/meals/#{meal.id}",
            params: { meal: { scheduled_time: "not-a-time" } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "404s when the meal id doesn't exist" do
      patch "/api/v1/meals/999999", params: { meal: { target_kcal: 600 } }.to_json, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "cross-tenant isolation" do
    let(:user_a) { Current.user }
    let(:user_b) { create(:user) }

    it "returns 404 for another user's meal" do
      b_meal = create(:meal, plan: create(:plan, user: user_b), user: user_b)
      patch "/api/v1/meals/#{b_meal.id}",
            params: { meal: { name: "x" } }.to_json,
            headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
