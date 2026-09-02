require "rails_helper"

RSpec.describe "GET /api/v1/plans", type: :request do
  before do
    stub_api_token
    seed_plan(slug: "exercise")
    seed_plan(slug: "active")
    seed_plan(slug: "rest")
  end

  it_behaves_like "food-gated endpoint" do
    let(:make_request) { -> { get "/api/v1/plans", headers: auth_headers } }
  end

  it "returns plans in canonical order with targets" do
    get "/api/v1/plans", headers: auth_headers
    expect(response).to have_http_status(:ok)
    plans = response.parsed_body["plans"]
    expect(plans.map { |p| p["slug"] }).to eq(%w[exercise active rest])
    expect(plans.first).to include("target_kcal", "target_protein_g", "target_carbs_g", "target_fat_g")
  end

  describe "cross-tenant isolation" do
    let(:user_a) { Current.user }
    let(:user_b) { create(:user) }

    it "does not return another user's plans" do
      seed_plan(slug: "exercise", user: user_a)  # idempotent — user_a already has one from the outer `before`
      user_b_plan = seed_plan(slug: "exercise", user: user_b)
      get "/api/v1/plans", headers: auth_headers
      plans = response.parsed_body["plans"]
      # Plan validates slug uniqueness scoped to user_id, so a scoped query returns
      # at most one plan per canonical slug (user_a's three). An unscoped query would
      # also return user_b's "exercise" plan, producing a duplicate-slug result that
      # this assertion rejects.
      expect(plans.map { |p| p["slug"] }).to eq(%w[exercise active rest])
      expect(plans.map { |p| p["id"] }).not_to include(user_b_plan.id)
    end
  end
end
