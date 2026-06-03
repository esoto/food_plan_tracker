require "rails_helper"

RSpec.describe "GET /api/v1/goals", type: :request do
  before do
    stub_api_token
    Goal.find_or_create_by!(metric: 0, user: Current.user) do |g|
      g.starting_value = 90
      g.target_value = 87
      g.unit = "kg"
      g.direction = "down"
      g.display_name = "Weight"
    end
  end

  it "returns goals with progress" do
    get "/api/v1/goals", headers: auth_headers
    expect(response).to have_http_status(:ok)
    goals = response.parsed_body["goals"]
    expect(goals).not_to be_empty
    weight = goals.find { |g| g["metric"] == "weight_kg" }
    expect(weight).to include("current_value", "target_value", "progress_pct")
  end

  describe "cross-tenant isolation" do
    let(:user_a) { Current.user }
    let(:user_b) { create(:user) }

    it "does not return another user's goals" do
      a = create(:goal, user: user_a)
      b = create(:goal, :weight, user: user_b) # different metric → no uniqueness collision
      get "/api/v1/goals", headers: auth_headers
      ids = response.parsed_body["goals"].map { |g| g["id"] }
      expect(ids).to include(a.id)
      expect(ids).not_to include(b.id)
    end
  end
end
