require "rails_helper"

RSpec.describe "Api::V1::DaysController", type: :request do
  before do
    stub_api_token
    seed_plan(slug: "active")
    seed_plan(slug: "exercise", target_kcal: 2200)
  end

  it_behaves_like "food-gated endpoint" do
    let(:make_request) { -> { get "/api/v1/days/#{Date.current.iso8601}", headers: auth_headers } }
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

  describe "cross-tenant isolation on update_plan" do
    let(:user_a) { Current.user }
    let(:user_b) { create(:user) }

    it "assigns the authenticated user's plan when both users share a slug" do
      user_b_plan = create(:plan, user: user_b, slug: "shared", name: "B shared")
      user_a_plan = create(:plan, user: user_a, slug: "shared", name: "A shared")
      date = (Date.current - 1).iso8601

      patch "/api/v1/days/#{date}/plan",
            params: { slug: "shared" }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("plan", "id")).to eq(user_a_plan.id)
      expect(DailyLog.find_by(user: user_a, date: date).plan_id).to eq(user_a_plan.id)
    end
  end
end
