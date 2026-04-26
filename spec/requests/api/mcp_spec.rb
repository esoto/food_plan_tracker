require "rails_helper"

RSpec.describe "POST /mcp", type: :request do
  let(:user)        { create(:user) }
  let(:application) { Doorkeeper::Application.create!(name: "Test Client", redirect_uri: "https://example.com/cb", scopes: "mcp", confidential: true) }
  let!(:token)      { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "mcp") }
  let(:plain_token) { token.plaintext_token }

  let(:auth) { { "Authorization" => "Bearer #{plain_token}", "Content-Type" => "application/json" } }

  before { seed_plan(slug: "active") }

  def rpc(method, params = nil, id: 1)
    body = { jsonrpc: "2.0", id: id, method: method }
    body[:params] = params if params
    post "/mcp", params: body.to_json, headers: auth
    response.parsed_body
  end

  describe "auth boundary" do
    it "rejects unauthenticated requests with 401" do
      post "/mcp",
           params: { jsonrpc: "2.0", id: 1, method: "initialize" }.to_json,
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects requests with the wrong bearer" do
      post "/mcp",
           params: { jsonrpc: "2.0", id: 1, method: "initialize" }.to_json,
           headers: { "Authorization" => "Bearer wrong", "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects valid tokens that lack the mcp scope" do
      other = Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "profile")
      post "/mcp",
           params: { jsonrpc: "2.0", id: 1, method: "initialize" }.to_json,
           headers: { "Authorization" => "Bearer #{other.plaintext_token}", "Content-Type" => "application/json" }
      expect(response).to have_http_status(:forbidden).or have_http_status(:unauthorized)
    end

    it "still requires a live token for notifications (revoked tokens get 401)" do
      token.revoke
      post "/mcp",
           params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json,
           headers: auth
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 405 on GET (we don't support server-initiated streams)" do
      get "/mcp", headers: auth
      expect(response).to have_http_status(:method_not_allowed)
    end
  end

  describe "initialize" do
    it "returns the protocol version, server info, and tool capability" do
      result = rpc("initialize")["result"]
      expect(result["protocolVersion"]).to eq("2025-06-18")
      expect(result["serverInfo"]).to include("name" => "food-tracker")
      expect(result["capabilities"]).to include("tools")
    end
  end

  describe "tools/list" do
    it "advertises every tool from the legacy stdio MCP plus list_meals" do
      tools = rpc("tools/list")["result"]["tools"]
      names = tools.map { |t| t["name"] }
      expect(names).to contain_exactly(
        "get_today_status", "get_day_status", "log_weight",
        "complete_meal", "uncomplete_meal", "log_food",
        "delete_logged_food", "set_plan_for_day", "list_goals",
        "search_foods", "create_food", "list_meals"
      )
      tools.each do |tool|
        expect(tool["inputSchema"]).to include("type" => "object")
        expect(tool["description"]).to be_present
      end
    end
  end

  describe "tools/call dispatch" do
    it "search_foods returns matches by partial name" do
      seed_food(name: "Chicken breast")
      seed_food(name: "Chickpeas", category: "carb")

      result = rpc("tools/call", { name: "search_foods", arguments: { q: "chick" } })["result"]
      payload = JSON.parse(result["content"].first["text"])
      expect(payload["foods"].map { |f| f["name"] }).to contain_exactly("Chicken breast", "Chickpeas")
    end

    it "create_food + log_food round-trips a new food into today's diary" do
      goal = Goal.find_or_create_by!(metric: Goal.metrics[:weight_kg]) do |g|
        g.display_name = "Weight"; g.unit = "kg"; g.direction = "down"
        g.starting_value = 80; g.target_value = 75
      end
      goal # touch so the let isn't unused

      create_args = { name: "Test omelette", category: "protein", serving_grams: 100,
                      kcal: 150, protein_g: 12, carbs_g: 1, fat_g: 11 }
      create_result = rpc("tools/call", { name: "create_food", arguments: create_args })["result"]
      expect(create_result).not_to include("isError" => true)

      log_result = rpc("tools/call", { name: "log_food", arguments: { name: "omelette" } })["result"]
      expect(log_result).not_to include("isError" => true)
      day = JSON.parse(log_result["content"].first["text"])["day"]
      expect(day["logged_foods"].first["food_name"]).to eq("Test omelette")
    end

    it "complete_meal returns isError when the meal name is unknown" do
      result = rpc("tools/call", { name: "complete_meal", arguments: { name: "Brunch" } })["result"]
      expect(result["isError"]).to be(true)
      expect(result["content"].first["text"]).to match(/no meal "Brunch"/)
    end

    it "log_weight records a biomarker entry and updates today's daily log" do
      Goal.find_or_create_by!(metric: Goal.metrics[:weight_kg]) do |g|
        g.display_name = "Weight"; g.unit = "kg"; g.direction = "down"
        g.starting_value = 80; g.target_value = 75
      end

      result = rpc("tools/call", { name: "log_weight", arguments: { value: 78.5 } })["result"]
      expect(result).not_to include("isError" => true)
      payload = JSON.parse(result["content"].first["text"])
      expect(payload["entry"]["value"]).to eq(78.5)
      expect(payload["day"]["weight_kg"]).to eq(78.5)
    end

    it "set_plan_for_day swaps the active plan and returns the new day shape" do
      seed_plan(slug: "rest", target_kcal: 1700)

      result = rpc("tools/call", { name: "set_plan_for_day", arguments: { slug: "rest" } })["result"]
      expect(result).not_to include("isError" => true)
      payload = JSON.parse(result["content"].first["text"])
      expect(payload["plan"]["slug"]).to eq("rest")
      expect(payload["targets"]["kcal"]).to eq(1700)
    end

    it "list_meals returns the 5 meals with per-item macros and totals for a plan" do
      result = rpc("tools/call", { name: "list_meals", arguments: { plan_slug: "active" } })["result"]
      expect(result).not_to include("isError" => true)
      payload = JSON.parse(result["content"].first["text"])
      expect(payload["plan"]["slug"]).to eq("active")
      expect(payload["meals"]).to be_an(Array)
      payload["meals"].each { |m| expect(m).to include("name", "totals", "items") }
    end

    it "delete_logged_food removes a previously logged food and returns the refreshed day" do
      food = seed_food(name: "Plain rice", category: "carb", serving_grams: 100, kcal: 130)
      log  = DailyLog.today
      entry = log.logged_foods.create!(food: food, quantity_grams: 50, logged_at: Time.current)

      result = rpc("tools/call", { name: "delete_logged_food", arguments: { id: entry.id } })["result"]
      expect(result).not_to include("isError" => true)
      payload = JSON.parse(result["content"].first["text"])
      expect(payload["day"]["logged_foods"].map { |lf| lf["id"] }).not_to include(entry.id)
    end

    it "tools/call returns isError on unknown tool" do
      result = rpc("tools/call", { name: "made_up_tool", arguments: {} })["result"]
      expect(result["isError"]).to be(true)
    end

    it "unknown JSON-RPC method returns -32601" do
      err = rpc("foo/bar")["error"]
      expect(err["code"]).to eq(-32601)
    end

    it "notifications (no id) get an empty 202" do
      post "/mcp",
           params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json,
           headers: auth
      expect(response).to have_http_status(:accepted)
    end
  end
end
