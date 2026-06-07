require "rails_helper"

RSpec.describe "Api::V1::MealCompletionsController", type: :request do
  let(:plan) { seed_plan(slug: "active") }
  let(:meal) do
    plan.meals.find_or_create_by!(name: "Breakfast") do |m|
      m.scheduled_time = Time.utc(2000, 1, 1, 7, 0)
      m.position = 1
      m.target_kcal = 400
      m.target_protein_g = 30
      m.target_carbs_g = 50
      m.target_fat_g = 10
    end
  end

  before { stub_api_token; meal }

  it "marks a meal complete and surfaces it in the day's snapshot" do
    post "/api/v1/meals/#{meal.id}/complete", params: {}.to_json, headers: auth_headers
    expect(response).to have_http_status(:created)
    expect(response.parsed_body["day"]["completed_meal_ids"]).to include(meal.id)
  end

  it "uncompletes a meal" do
    DailyLog.today.meal_completions.create!(meal: meal, completed_at: Time.current)
    delete "/api/v1/meals/#{meal.id}/complete", params: {}.to_json, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["day"]["completed_meal_ids"]).not_to include(meal.id)
  end

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }
    let(:b_meal) { create(:meal, plan: create(:plan, user: user_b), user: user_b) }

    it "completing another user's meal returns 404 and does not create a completion" do
      post "/api/v1/meals/#{b_meal.id}/complete",
           params: { date: Date.current.iso8601 }.to_json, headers: auth_headers
      expect(response).to have_http_status(:not_found)
      expect(MealCompletion.where(meal: b_meal).count).to eq(0)
    end
  end
end
