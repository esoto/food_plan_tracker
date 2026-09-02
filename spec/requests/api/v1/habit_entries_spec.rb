require "rails_helper"

RSpec.describe "Api::V1::HabitEntriesController", type: :request do
  before do
    stub_api_token
    Habit.delete_all
    DailyLog.delete_all
    seed_plan(slug: "active")
  end

  describe "POST /api/v1/habits/:habit_id/entries" do
    let(:user) { Current.user }

    it "sets the value on a binary habit" do
      habit = create(:habit, user: user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 1 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["habit"]["id"]).to eq(habit.id)
      expect(body["entry"]).to include(
        "habit_id" => habit.id,
        "date"     => Date.current.iso8601,
        "value"    => 1.0,
        "done"     => true
      )
    end

    it "sets done=false for a binary habit when value is not 1" do
      habit = create(:habit, user: user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 0 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["entry"]["done"]).to eq(false)
    end

    it "sets done=false for a quantity habit when target is not met" do
      habit = create(:habit, :quantity, user: user, target_value: 3)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 1 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["entry"]["done"]).to eq(false)
    end

    it "sets done=true for a quantity habit when target is met" do
      habit = create(:habit, :quantity, user: user, target_value: 3)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 3 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["entry"]["done"]).to eq(true)
    end

    it "accumulates delta across two calls" do
      habit = create(:habit, :quantity, user: user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { delta: 2 } }.to_json,
           headers: auth_headers
      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { delta: 3 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["entry"]["value"]).to eq(5.0)
    end

    it "resets value when value: 0 is passed" do
      habit = create(:habit, :quantity, user: user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 5 } }.to_json,
           headers: auth_headers
      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 0 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["entry"]["value"]).to eq(0.0)
    end

    it "returns 404 for an archived habit" do
      habit = create(:habit, user: user, discarded_at: 1.day.ago)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: { value: 1 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(HabitEntry.where(habit: habit)).not_to exist
    end

    it "returns 404 for another user's habit and writes nothing" do
      other_habit = create(:habit, label: "Theirs", user: create(:user))

      post "/api/v1/habits/#{other_habit.id}/entries",
           params: { entry: { value: 1 } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(HabitEntry.where(habit: other_habit)).not_to exist
    end

    it "returns 422 when value is missing entirely (no entry object)" do
      habit = create(:habit, user: user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { entry: {} }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to have_key("error")
    end

    it "returns 400 when value is missing entirely (no entry object)" do
      habit = create(:habit, user: user)

      post "/api/v1/habits/#{habit.id}/entries",
           params: { }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to have_key("error")
    end
  end
end