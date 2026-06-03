require "rails_helper"

RSpec.describe "Api::V1::SupplementsController", type: :request do
  before { stub_api_token }

  describe "GET /api/v1/supplements" do
    it "lists kept supplements with their time slots" do
      sup = create(:supplement, name: "Magnesium", user: Current.user)
      sup.supplement_schedules.create!(time_slot: "pre_sleep", position: 0)
      create(:supplement, name: "Archived stack", discarded_at: 1.day.ago, user: Current.user)

      get "/api/v1/supplements", headers: auth_headers

      expect(response).to have_http_status(:ok)
      names = response.parsed_body["supplements"].map { |s| s["name"] }
      expect(names).to include("Magnesium")
      expect(names).not_to include("Archived stack")
      mag = response.parsed_body["supplements"].find { |s| s["name"] == "Magnesium" }
      expect(mag["time_slots"]).to eq([ "pre_sleep" ])
    end

    it "returns archived list when archived=true" do
      create(:supplement, name: "Active", user: Current.user)
      create(:supplement, name: "Archived stack", discarded_at: 1.day.ago, user: Current.user)

      get "/api/v1/supplements?archived=true", headers: auth_headers

      names = response.parsed_body["supplements"].map { |s| s["name"] }
      expect(names).to contain_exactly("Archived stack")
    end
  end

  describe "POST /api/v1/supplements" do
    it "creates a supplement and assigns time slots" do
      payload = {
        supplement: { name: "Vitamin D", dose: "5000 IU", critical: false },
        time_slots: [ "morning", "dinner" ]
      }
      expect {
        post "/api/v1/supplements", params: payload.to_json, headers: auth_headers
      }.to change(Supplement, :count).by(1).and change(SupplementSchedule, :count).by(2)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["supplement"]["time_slots"]).to contain_exactly("morning", "dinner")
    end

    it "422s on validation failure" do
      post "/api/v1/supplements", params: { supplement: { name: "" } }.to_json, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/supplements/:id" do
    it "updates fields and reconciles slots when time_slots provided" do
      sup = create(:supplement, name: "Old", user: Current.user)
      sup.supplement_schedules.create!(time_slot: "morning", position: 0)

      patch "/api/v1/supplements/#{sup.id}",
            params: { supplement: { name: "New" }, time_slots: [ "dinner" ] }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(sup.reload.name).to eq("New")
      expect(sup.supplement_schedules.pluck(:time_slot)).to contain_exactly("dinner")
    end

    it "leaves slots untouched when time_slots key omitted" do
      sup = create(:supplement, user: Current.user)
      sup.supplement_schedules.create!(time_slot: "morning", position: 0)

      patch "/api/v1/supplements/#{sup.id}",
            params: { supplement: { name: "Renamed" } }.to_json,
            headers: auth_headers

      expect(sup.reload.supplement_schedules.pluck(:time_slot)).to contain_exactly("morning")
    end
  end

  describe "DELETE /api/v1/supplements/:id" do
    it "soft-deletes" do
      sup = create(:supplement, user: Current.user)
      delete "/api/v1/supplements/#{sup.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(sup.reload.discarded_at).to be_present
    end
  end

  describe "PATCH /api/v1/supplements/:id/restore" do
    it "clears discarded_at" do
      sup = create(:supplement, discarded_at: 1.day.ago, user: Current.user)
      patch "/api/v1/supplements/#{sup.id}/restore", headers: auth_headers
      expect(sup.reload.discarded_at).to be_nil
    end
  end

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }

    it "index does not return another user's supplements" do
      create(:supplement, name: "Mine",   user: Current.user)
      create(:supplement, name: "Theirs", user: user_b)
      get "/api/v1/supplements", headers: auth_headers
      names = response.parsed_body["supplements"].map { |s| s["name"] }
      expect(names).to include("Mine")
      expect(names).not_to include("Theirs")
    end

    it "PATCH another user's supplement returns 404" do
      b = create(:supplement, user: user_b)
      patch "/api/v1/supplements/#{b.id}", params: { supplement: { name: "x" } }.to_json, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "DELETE another user's supplement returns 404 and does not discard it" do
      b = create(:supplement, user: user_b)
      delete "/api/v1/supplements/#{b.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).to be_nil
    end

    it "restore on another user's supplement returns 404" do
      b = create(:supplement, user: user_b, discarded_at: 1.day.ago)
      patch "/api/v1/supplements/#{b.id}/restore", headers: auth_headers
      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).not_to be_nil
    end
  end
end
