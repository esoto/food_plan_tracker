require "rails_helper"

RSpec.describe "POST /api/v1/weight", type: :request do
  let(:user) { create(:user) }

  before do
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
    stub_api_token
    seed_plan(slug: "active")
    Goal.find_or_create_by!(metric: 0, user: user) do |g|
      g.starting_value = 90
      g.target_value = 87
      g.unit = "kg"
      g.direction = "down"
      g.display_name = "Weight"
    end
  end

  it "creates a biomarker entry and updates today's daily_log" do
    expect {
      post "/api/v1/weight", params: { value: 86.4 }.to_json, headers: auth_headers
    }.to change(BiomarkerEntry, :count).by(1)

    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body["entry"]["value"]).to eq(86.4)
    expect(body["day"]["weight_kg"]).to eq(86.4)
  end

  it "supports backfilling a past date" do
    date = (Date.current - 2).iso8601
    post "/api/v1/weight", params: { value: 87.1, date: date }.to_json, headers: auth_headers
    expect(response).to have_http_status(:created)
    expect(BiomarkerEntry.last.recorded_on.iso8601).to eq(date)
    expect(DailyLog.find_by(date: date).weight_kg.to_f).to eq(87.1)
  end

  it "returns 422 when the value is missing" do
    post "/api/v1/weight", params: {}.to_json, headers: auth_headers
    expect(response).to have_http_status(:bad_request)
  end

  describe "cross-tenant isolation" do
    it "does not write a weight entry onto another user's goal" do
      # The outer `before` already created user_a's weight goal. Delete it,
      # then create user_b's weight goal (gets the lowest id), then recreate
      # user_a's (higher id). With unscoped `find_by!`, the controller
      # resolves user_b's goal and the biomarker entry lands on user_b's
      # (reload count == 1, RED). With the scoped
      # `find_by_metric!(..., user: Current.user)`, the controller resolves
      # user_a's goal and the entry lands on user_a's (b_goal count == 0,
      # GREEN).
      user_a_goal = user.goals.find_by(metric: Goal.metrics[:weight_kg])
      user_a_goal&.destroy
      user_b = create(:user)
      b_goal = create(:goal, :weight, user: user_b)
      user_a_goal = create(:goal, :weight, user: user)

      post "/api/v1/weight", params: { value: 86.4 }.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(b_goal.reload.biomarker_entries.count).to eq(0)
      # Sanity: the controller actually wrote — but to user_a's goal, not user_b's.
      expect(user_a_goal.reload.biomarker_entries.count).to eq(1)
    end
  end
end
