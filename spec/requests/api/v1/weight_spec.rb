require "rails_helper"

RSpec.describe "POST /api/v1/weight", type: :request do
  before do
    stub_api_token
    seed_plan(slug: "active")
    Goal.find_or_create_by!(metric: 0) do |g|
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
end
