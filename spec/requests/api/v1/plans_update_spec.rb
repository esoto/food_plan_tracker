require "rails_helper"

RSpec.describe "Api::V1::PlansController#update", type: :request do
  before { stub_api_token }

  let(:plan) { create(:plan, target_kcal: 2000, target_protein_g: 180, target_carbs_g: 180, target_fat_g: 80) }

  describe "PATCH /api/v1/plans/:id" do
    it "updates macro targets and returns the serialized plan" do
      patch "/api/v1/plans/#{plan.id}",
            params: { plan: { target_kcal: 2200, target_protein_g: 200 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["plan"]
      expect(body["target_kcal"]).to eq(2200)
      expect(body["target_protein_g"]).to eq(200.0)
      expect(plan.reload.target_kcal).to eq(2200)
      expect(plan.target_carbs_g).to eq(180)
    end

    it "rejects non-positive macro values with 422" do
      patch "/api/v1/plans/#{plan.id}",
            params: { plan: { target_kcal: 0 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(plan.reload.target_kcal).to eq(2000)
    end

    it "ignores fields outside the macro target whitelist" do
      original_slug = plan.slug
      patch "/api/v1/plans/#{plan.id}",
            params: { plan: { slug: "tampered", target_kcal: 2100 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(plan.reload.slug).to eq(original_slug)
      expect(plan.target_kcal).to eq(2100)
    end

    it "404s when the plan id doesn't exist" do
      patch "/api/v1/plans/999999", params: { plan: { target_kcal: 2100 } }.to_json, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
