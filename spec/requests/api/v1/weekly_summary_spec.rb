require "rails_helper"

RSpec.describe "GET /api/v1/weekly_summary", type: :request do
  let!(:plan) { seed_plan(slug: "active") }
  let!(:weight_goal) do
    Goal.find_or_create_by!(metric: :weight_kg) do |g|
      g.display_name = "Weight"
      g.unit = "kg"
      g.direction = :down
      g.starting_value = 88.0
      g.target_value = 82.0
    end
  end

  before { stub_api_token }

  it "returns 401 without a token" do
    get "/api/v1/weekly_summary"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns the rolling 7-day window with all four metrics" do
    travel_to Time.zone.local(2026, 4, 25, 12, 0) do
      weight_goal.biomarker_entries.create!(recorded_on: Date.current - 6, value: 86.0)
      weight_goal.biomarker_entries.create!(recorded_on: Date.current,     value: 85.4)

      get "/api/v1/weekly_summary", headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["window_days"]).to eq(7)
      expect(body["start_date"]).to eq("2026-04-19")
      expect(body["end_date"]).to eq("2026-04-25")
      expect(body["weight_delta_kg"]).to eq(-0.6)
      expect(body).to have_key("adherence_pct")
      expect(body).to have_key("meal_completion_pct")
      expect(body).to have_key("supplement_completion_pct")
    end
  end

  it "serializes nil metrics as null" do
    DailyLog.destroy_all
    Supplement.destroy_all

    get "/api/v1/weekly_summary", headers: auth_headers

    body = response.parsed_body
    expect(body["adherence_pct"]).to be_nil
    expect(body["meal_completion_pct"]).to be_nil
    expect(body["supplement_completion_pct"]).to be_nil
  end
end
