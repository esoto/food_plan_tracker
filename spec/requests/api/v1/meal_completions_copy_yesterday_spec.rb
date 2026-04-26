require "rails_helper"

RSpec.describe "POST /api/v1/meal_completions/copy_yesterday", type: :request do
  let!(:plan) { seed_plan(slug: "active") }
  let!(:other_plan) { seed_plan(slug: "exercise", target_kcal: 2200) }
  let!(:breakfast) do
    plan.meals.create!(position: 1, name: "Breakfast",
                       scheduled_time: Time.utc(2000, 1, 1, 7, 0),
                       target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10)
  end
  let!(:lunch) do
    plan.meals.create!(position: 2, name: "Lunch",
                       scheduled_time: Time.utc(2000, 1, 1, 12, 30),
                       target_kcal: 600, target_protein_g: 45, target_carbs_g: 60, target_fat_g: 20)
  end

  before { stub_api_token }

  it "returns 401 without a token" do
    post "/api/v1/meal_completions/copy_yesterday"
    expect(response).to have_http_status(:unauthorized)
  end

  it "copies yesterday's completions and returns the count" do
    yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
    yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)
    yesterday.meal_completions.create!(meal: lunch, completed_at: 1.day.ago)

    expect {
      post "/api/v1/meal_completions/copy_yesterday", headers: auth_headers
    }.to change { DailyLog.today.meal_completions.count }.from(0).to(2)

    body = response.parsed_body
    expect(body["copied"]).to eq(2)
    expect(body["day"]["completed_meal_ids"]).to contain_exactly(breakfast.id, lunch.id)
  end

  it "returns plan_mismatch when yesterday has a different plan" do
    yesterday = DailyLog.create!(date: Date.current - 1, plan: other_plan)
    yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)
    DailyLog.today

    expect {
      post "/api/v1/meal_completions/copy_yesterday", headers: auth_headers
    }.not_to change(MealCompletion, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to eq("plan_mismatch")
  end

  it "returns no_yesterday_log when there is no yesterday" do
    DailyLog.where(date: Date.current - 1).destroy_all

    post "/api/v1/meal_completions/copy_yesterday", headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to eq("no_yesterday_log")
  end

  it "respects an explicit date param (backfilling onto a past day)" do
    target_date = Date.current - 3
    day_before = DailyLog.create!(date: target_date - 1, plan: plan)
    day_before.meal_completions.create!(meal: breakfast, completed_at: target_date - 1)

    post "/api/v1/meal_completions/copy_yesterday",
         params: { date: target_date.iso8601 }.to_json,
         headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["copied"]).to eq(1)
    expect(DailyLog.find_by(date: target_date).meal_completions.count).to eq(1)
  end
end
