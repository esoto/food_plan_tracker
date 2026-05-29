require "rails_helper"

RSpec.describe "Api::V1::HabitsController", type: :request do
  before do
    stub_api_token
    ChecklistTemplate.delete_all
  end

  describe "GET /api/v1/habits" do
    it "lists kept habits in display order" do
      create(:checklist_template, label: "B", position: 1)
      create(:checklist_template, label: "A", position: 0)
      create(:checklist_template, label: "Old", position: 2, discarded_at: 1.day.ago)

      get "/api/v1/habits", headers: auth_headers

      expect(response).to have_http_status(:ok)
      labels = response.parsed_body["habits"].map { |h| h["label"] }
      expect(labels).to eq([ "A", "B" ])
    end

    it "returns archived list when archived=true" do
      create(:checklist_template, label: "Active", position: 0)
      create(:checklist_template, label: "Old", position: 1, discarded_at: 1.day.ago)

      get "/api/v1/habits?archived=true", headers: auth_headers

      labels = response.parsed_body["habits"].map { |h| h["label"] }
      expect(labels).to contain_exactly("Old")
    end
  end

  describe "POST /api/v1/habits" do
    it "appends at the end of the position list" do
      create(:checklist_template, label: "First", position: 0, user: Current.user)

      post "/api/v1/habits", params: { habit: { label: "Second" } }.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["habit"]["position"]).to eq(1)
    end
  end

  describe "PATCH /api/v1/habits/:id" do
    it "updates fields including position" do
      template = create(:checklist_template, label: "Old", position: 0)
      patch "/api/v1/habits/#{template.id}",
            params: { habit: { label: "New", position: 5 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(template.reload.label).to eq("New")
      expect(template.position).to eq(5)
    end
  end

  describe "DELETE /api/v1/habits/:id" do
    it "soft-deletes" do
      template = create(:checklist_template, position: 0)
      delete "/api/v1/habits/#{template.id}", headers: auth_headers
      expect(template.reload.discarded_at).to be_present
    end
  end

  describe "PATCH /api/v1/habits/:id/restore" do
    it "restores at the end of the position list" do
      create(:checklist_template, label: "A", position: 0, user: Current.user)
      create(:checklist_template, label: "B", position: 1, user: Current.user)
      restored = create(:checklist_template, label: "Old", position: 2, discarded_at: 1.day.ago, user: Current.user)

      patch "/api/v1/habits/#{restored.id}/restore", headers: auth_headers

      expect(restored.reload.discarded_at).to be_nil
      expect(restored.position).to eq(2)
    end
  end
end
