require "rails_helper"

RSpec.describe "Api::V1::DaysController", type: :request do
  before do
    stub_api_token
    seed_plan(slug: "active")
    seed_plan(slug: "exercise", target_kcal: 2200)
  end

  describe "GET /api/v1/days/:date" do
    it "returns the snapshot for a past date" do
      date = (Date.current - 3).iso8601
      get "/api/v1/days/#{date}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["date"]).to eq(date)
    end

    it "returns 400 for an invalid date" do
      get "/api/v1/days/2026-99-99", headers: auth_headers
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "PATCH /api/v1/days/:date/plan" do
    it "switches the plan for that day" do
      date = (Date.current - 1).iso8601
      patch "/api/v1/days/#{date}/plan",
            params: { slug: "exercise" }.to_json,
            headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("plan", "slug")).to eq("exercise")
      expect(DailyLog.find_by(date: date).plan.slug).to eq("exercise")
    end

    it "returns 404 when slug is unknown" do
      patch "/api/v1/days/#{(Date.current - 1).iso8601}/plan",
            params: { slug: "nope" }.to_json,
            headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
