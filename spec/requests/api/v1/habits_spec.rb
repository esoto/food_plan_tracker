require "rails_helper"

RSpec.describe "Api::V1::HabitsController", type: :request do
  before do
    stub_api_token
    Habit.delete_all
  end

  describe "GET /api/v1/habits" do
    it "lists kept habits in display order" do
      create(:habit, label: "B", position: 1, user: Current.user)
      create(:habit, label: "A", position: 0, user: Current.user)
      create(:habit, label: "Old", position: 2, discarded_at: 1.day.ago, user: Current.user)

      get "/api/v1/habits", headers: auth_headers

      expect(response).to have_http_status(:ok)
      labels = response.parsed_body["habits"].map { |h| h["label"] }
      expect(labels).to eq([ "A", "B" ])
    end

    it "returns archived list when archived=true" do
      create(:habit, label: "Active", position: 0, user: Current.user)
      create(:habit, label: "Old", position: 1, discarded_at: 1.day.ago, user: Current.user)

      get "/api/v1/habits?archived=true", headers: auth_headers

      labels = response.parsed_body["habits"].map { |h| h["label"] }
      expect(labels).to contain_exactly("Old")
    end

    it "includes kind/unit/target_value/rating_scale on each habit" do
      create(:habit, :quantity, label: "Water", position: 0, user: Current.user)

      get "/api/v1/habits", headers: auth_headers

      habit = response.parsed_body["habits"].first
      expect(habit["kind"]).to eq("quantity")
      expect(habit["unit"]).to eq("glasses")
      expect(habit["target_value"]).to eq("8.0")
      expect(habit).to have_key("rating_scale")
    end
  end

  describe "POST /api/v1/habits" do
    it "appends at the end of the position list" do
      create(:habit, label: "First", position: 0, user: Current.user)

      post "/api/v1/habits", params: { habit: { label: "Second" } }.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["habit"]["position"]).to eq(1)
    end

    it "creates a rating habit with kind and rating_scale" do
      post "/api/v1/habits",
           params: { habit: { label: "Mood", kind: "rating", rating_scale: 5 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      habit = response.parsed_body["habit"]
      expect(habit["kind"]).to eq("rating")
      expect(habit["rating_scale"]).to eq(5)
    end
  end

  describe "PATCH /api/v1/habits/:id" do
    it "updates fields including position" do
      habit = create(:habit, label: "Old", position: 0, user: Current.user)
      patch "/api/v1/habits/#{habit.id}",
            params: { habit: { label: "New", position: 5 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(habit.reload.label).to eq("New")
      expect(habit.position).to eq(5)
    end

    it "ignores a kind param — kind is immutable after creation" do
      habit = create(:habit, :quantity, label: "Water", position: 0, user: Current.user)

      patch "/api/v1/habits/#{habit.id}",
            params: { habit: { kind: "duration" } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(habit.reload.kind).to eq("quantity")
      expect(response.parsed_body["habit"]["kind"]).to eq("quantity")
    end
  end

  describe "DELETE /api/v1/habits/:id" do
    it "soft-deletes" do
      habit = create(:habit, position: 0, user: Current.user)
      delete "/api/v1/habits/#{habit.id}", headers: auth_headers
      expect(habit.reload.discarded_at).to be_present
    end
  end

  describe "PATCH /api/v1/habits/:id/restore" do
    it "restores at the end of the position list" do
      create(:habit, label: "A", position: 0, user: Current.user)
      create(:habit, label: "B", position: 1, user: Current.user)
      restored = create(:habit, label: "Old", position: 2, discarded_at: 1.day.ago, user: Current.user)

      patch "/api/v1/habits/#{restored.id}/restore", headers: auth_headers

      expect(restored.reload.discarded_at).to be_nil
      expect(restored.position).to eq(2)
    end
  end

  describe "cross-tenant isolation" do
    # NOTE: each `it` block creates user_b's records locally so they survive
    # the outer `before { Habit.delete_all }` hook.
    let(:user_b) { create(:user) }

    it "index does not return another user's habits" do
      create(:habit, label: "Mine", position: 0, user: Current.user)
      create(:habit, label: "Theirs", position: 1, user: user_b)

      get "/api/v1/habits", headers: auth_headers

      labels = response.parsed_body["habits"].map { |h| h["label"] }
      expect(labels).to include("Mine")
      expect(labels).not_to include("Theirs")
    end

    it "PATCH another user's habit returns 404 and does not mutate it" do
      b = create(:habit, label: "Theirs", position: 0, user: user_b)

      patch "/api/v1/habits/#{b.id}",
            params: { habit: { label: "x" } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(b.reload.label).to eq("Theirs")
    end

    it "DELETE another user's habit returns 404 and does not discard it" do
      b = create(:habit, label: "Theirs", position: 0, user: user_b)

      delete "/api/v1/habits/#{b.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).to be_nil
    end

    it "restore on another user's habit returns 404 and does not restore it" do
      b = create(:habit, label: "Theirs", position: 0,
                 discarded_at: 1.day.ago, user: user_b)

      patch "/api/v1/habits/#{b.id}/restore", headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).not_to be_nil
    end
  end
end
