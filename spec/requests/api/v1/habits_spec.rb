require "rails_helper"

RSpec.describe "Api::V1::HabitsController", type: :request do
  before do
    stub_api_token
    ChecklistTemplate.delete_all
  end

  describe "GET /api/v1/habits" do
    it "lists kept habits in display order" do
      create(:checklist_template, label: "B", position: 1, user: Current.user)
      create(:checklist_template, label: "A", position: 0, user: Current.user)
      create(:checklist_template, label: "Old", position: 2, discarded_at: 1.day.ago, user: Current.user)

      get "/api/v1/habits", headers: auth_headers

      expect(response).to have_http_status(:ok)
      labels = response.parsed_body["habits"].map { |h| h["label"] }
      expect(labels).to eq([ "A", "B" ])
    end

    it "returns archived list when archived=true" do
      create(:checklist_template, label: "Active", position: 0, user: Current.user)
      create(:checklist_template, label: "Old", position: 1, discarded_at: 1.day.ago, user: Current.user)

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
      template = create(:checklist_template, label: "Old", position: 0, user: Current.user)
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
      template = create(:checklist_template, position: 0, user: Current.user)
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

  describe "cross-tenant isolation" do
    # NOTE: each `it` block creates user_b's records locally so they survive
    # the outer `before { ChecklistTemplate.delete_all }` hook.
    let(:user_b) { create(:user) }

    it "index does not return another user's habits" do
      create(:checklist_template, label: "Mine", position: 0, user: Current.user)
      create(:checklist_template, label: "Theirs", position: 1, user: user_b)

      get "/api/v1/habits", headers: auth_headers

      labels = response.parsed_body["habits"].map { |h| h["label"] }
      expect(labels).to include("Mine")
      expect(labels).not_to include("Theirs")
    end

    it "PATCH another user's habit returns 404" do
      b = create(:checklist_template, label: "Theirs", position: 0, user: user_b)

      patch "/api/v1/habits/#{b.id}",
            params: { habit: { label: "x" } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "DELETE another user's habit returns 404 and does not discard it" do
      b = create(:checklist_template, label: "Theirs", position: 0, user: user_b)

      delete "/api/v1/habits/#{b.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).to be_nil
    end
  end
end
