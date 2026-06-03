require "rails_helper"

RSpec.describe "GET /api/v1/weekly_summary", type: :request do
  let(:user) { create(:user) }
  let!(:plan) { seed_plan(slug: "active") }
  let!(:weight_goal) do
    Goal.find_or_create_by!(metric: :weight_kg, user: user) do |g|
      g.display_name = "Weight"
      g.unit = "kg"
      g.direction = :down
      g.starting_value = 88.0
      g.target_value = 82.0
    end
  end

  before do
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
    stub_api_token
  end

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
    weight_goal.biomarker_entries.destroy_all

    get "/api/v1/weekly_summary", headers: auth_headers

    body = response.parsed_body
    expect(body["adherence_pct"]).to be_nil
    expect(body["weight_delta_kg"]).to be_nil
    expect(body["meal_completion_pct"]).to be_nil
    expect(body["supplement_completion_pct"]).to be_nil
  end

  describe "cross-tenant isolation" do
    it "does not include another user's logs/entries in the summary" do
      user_b = create(:user)
      b_plan = create(:plan, user: user_b)
      create(:daily_log, user: user_b, plan: b_plan, date: Date.current - 1)
      create(:daily_log, user: user_b, plan: b_plan, date: Date.current - 2)
      b_goal = create(:goal, :weight, user: user_b)
      b_goal.biomarker_entries.create!(recorded_on: Date.current - 6, value: 90.0)
      b_goal.biomarker_entries.create!(recorded_on: Date.current,     value: 85.0)
      # user_a has no logs/entries in the window

      get "/api/v1/weekly_summary", headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["weight_delta_kg"]).to be_nil
      expect(body["adherence_pct"]).to be_nil
    end
  end
end
