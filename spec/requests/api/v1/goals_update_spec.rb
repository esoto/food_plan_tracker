require "rails_helper"

RSpec.describe "Api::V1::GoalsController#update", type: :request do
  before { stub_api_token }

  let(:goal) { create(:goal, :weight, user: Current.user, target_value: 80) }

  describe "PATCH /api/v1/goals/:id" do
    it "updates target_value" do
      patch "/api/v1/goals/#{goal.id}",
            params: { goal: { target_value: 78.5 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["goal"]["target_value"]).to eq(78.5)
      expect(goal.reload.target_value.to_f).to eq(78.5)
    end

    it "rejects non-numeric target_value with 422" do
      patch "/api/v1/goals/#{goal.id}",
            params: { goal: { target_value: "not-a-number" } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "ignores fields outside the target_value whitelist" do
      original_metric = goal.metric
      patch "/api/v1/goals/#{goal.id}",
            params: { goal: { metric: "hdl", target_value: 79 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(goal.reload.metric).to eq(original_metric)
      expect(goal.target_value.to_f).to eq(79)
    end

    it "400s when the :goal key is omitted from the body" do
      patch "/api/v1/goals/#{goal.id}", params: {}.to_json, headers: auth_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "404s when the goal id doesn't exist" do
      patch "/api/v1/goals/999999", params: { goal: { target_value: 78 } }.to_json, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "cross-tenant isolation" do
    let(:user_a) { Current.user }
    let(:user_b) { create(:user) }

    it "returns 404 for another user's goal" do
      b = create(:goal, :weight, user: user_b, target_value: 50)
      patch "/api/v1/goals/#{b.id}", params: { goal: { target_value: 99 } }.to_json, headers: auth_headers
      expect(response).to have_http_status(:not_found)
      expect(b.reload.target_value).to eq(50)
    end
  end
end
