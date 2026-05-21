require "rails_helper"

RSpec.describe "GET /api/v1/goals", type: :request do
  let(:user) { create(:user) }

  before do
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
    stub_api_token
    Goal.find_or_create_by!(metric: 0, user: user) do |g|
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
end
