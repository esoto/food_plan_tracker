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
        "search_foods", "create_food", "list_meals",
        "get_weekly_summary", "copy_yesterday_meals",
        "list_supplements", "create_supplement", "update_supplement",
        "archive_supplement", "restore_supplement",
        "list_habits", "create_habit", "update_habit",
        "archive_habit", "restore_habit"
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

    describe "get_weekly_summary" do
      let!(:weight_goal) do
        Goal.find_or_create_by!(metric: Goal.metrics[:weight_kg]) do |g|
          g.display_name = "Weight"; g.unit = "kg"; g.direction = "down"
          g.starting_value = 88; g.target_value = 82
        end
      end

      it "returns the rolling 7-day metrics" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          weight_goal.biomarker_entries.create!(recorded_on: Date.current - 6, value: 86.0)
          weight_goal.biomarker_entries.create!(recorded_on: Date.current,     value: 85.4)

          result = rpc("tools/call", { name: "get_weekly_summary", arguments: {} })["result"]
          payload = JSON.parse(result["content"].first["text"])

          expect(payload).to include(
            "window_days" => 7,
            "start_date" => "2026-04-19",
            "end_date" => "2026-04-25",
            "weight_delta_kg" => -0.6
          )
          expect(payload).to have_key("adherence_pct")
          expect(payload).to have_key("meal_completion_pct")
          expect(payload).to have_key("supplement_completion_pct")
        end
      end

      it "returns null metrics when the window has no data" do
        DailyLog.destroy_all
        Supplement.destroy_all
        weight_goal.biomarker_entries.destroy_all

        result = rpc("tools/call", { name: "get_weekly_summary", arguments: {} })["result"]
        payload = JSON.parse(result["content"].first["text"])

        expect(payload["adherence_pct"]).to be_nil
        expect(payload["weight_delta_kg"]).to be_nil
        expect(payload["meal_completion_pct"]).to be_nil
        expect(payload["supplement_completion_pct"]).to be_nil
      end
    end

    describe "copy_yesterday_meals" do
      let!(:breakfast) do
        Plan.find_by(slug: "active").meals.create!(
          position: 1, name: "Breakfast",
          scheduled_time: Time.utc(2000, 1, 1, 7, 0),
          target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10
        )
      end

      it "copies yesterday's completions onto today and reports the count" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          plan = Plan.find_by(slug: "active")
          yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
          yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)

          result = rpc("tools/call", { name: "copy_yesterday_meals", arguments: {} })["result"]
          payload = JSON.parse(result["content"].first["text"])

          expect(payload["copied"]).to eq(1)
          expect(DailyLog.today.meal_completions.count).to eq(1)
        end
      end

      it "is idempotent — re-invocation reports copied: 0 and preserves prior completions" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          plan = Plan.find_by(slug: "active")
          yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
          yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)

          rpc("tools/call", { name: "copy_yesterday_meals", arguments: {} })
          first_completion = DailyLog.today.meal_completions.find_by!(meal: breakfast)
          first_timestamp = first_completion.completed_at

          result = rpc("tools/call", { name: "copy_yesterday_meals", arguments: {} })["result"]
          payload = JSON.parse(result["content"].first["text"])

          expect(payload["copied"]).to eq(0)
          expect(DailyLog.today.meal_completions.count).to eq(1)
          expect(first_completion.reload.completed_at).to eq(first_timestamp)
        end
      end

      it "is an error when there is no yesterday log" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          DailyLog.where(date: Date.current - 1).destroy_all

          result = rpc("tools/call", { name: "copy_yesterday_meals", arguments: {} })["result"]
          expect(result["isError"]).to be(true)
          expect(result["content"].first["text"]).to match(/no_yesterday_log/)
        end
      end

      it "is an error when plans differ" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          other_plan = seed_plan(slug: "exercise", target_kcal: 2200)
          DailyLog.create!(date: Date.current - 1, plan: other_plan)
            .meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)
          DailyLog.today

          result = rpc("tools/call", { name: "copy_yesterday_meals", arguments: {} })["result"]
          expect(result["isError"]).to be(true)
          expect(result["content"].first["text"]).to match(/plan_mismatch/)
        end
      end

      it "does not create a phantom DailyLog when the request fails" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          target_date = Date.current - 5
          DailyLog.where(date: target_date - 1).destroy_all
          DailyLog.where(date: target_date).destroy_all

          expect {
            rpc("tools/call", { name: "copy_yesterday_meals", arguments: { date: target_date.iso8601 } })
          }.not_to change { DailyLog.where(date: target_date).count }
        end
      end
    end

    describe "supplements management" do
      it "list_supplements returns kept supplements with their time slots" do
        sup = create(:supplement, name: "Magnesium")
        sup.supplement_schedules.create!(time_slot: "pre_sleep", position: 0)
        create(:supplement, name: "Archived stack", discarded_at: 1.day.ago)

        result = rpc("tools/call", { name: "list_supplements", arguments: {} })["result"]
        payload = JSON.parse(result["content"].first["text"])
        names = payload["supplements"].map { |s| s["name"] }
        expect(names).to include("Magnesium")
        expect(names).not_to include("Archived stack")
      end

      it "create_supplement with time_slots assigns the schedule rows" do
        result = rpc("tools/call", { name: "create_supplement",
                                     arguments: { name: "Vitamin D", dose: "5000 IU",
                                                  time_slots: [ "morning" ] } })["result"]
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["supplement"]["time_slots"]).to eq([ "morning" ])
      end

      it "update_supplement is an error when no updatable field or time_slots sent" do
        sup = create(:supplement)
        result = rpc("tools/call", { name: "update_supplement", arguments: { id: sup.id } })["result"]
        expect(result["isError"]).to be(true)
      end

      it "archive_supplement and restore_supplement round-trip" do
        sup = create(:supplement)

        rpc("tools/call", { name: "archive_supplement", arguments: { id: sup.id } })
        expect(sup.reload.discarded_at).to be_present

        rpc("tools/call", { name: "restore_supplement", arguments: { id: sup.id } })
        expect(sup.reload.discarded_at).to be_nil
      end
    end

    describe "habits management" do
      before { ChecklistTemplate.delete_all }

      it "create_habit appends at the end of the position list" do
        create(:checklist_template, label: "First", position: 0)

        result = rpc("tools/call", { name: "create_habit", arguments: { label: "Second" } })["result"]
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["habit"]["position"]).to eq(1)
      end

      it "update_habit is an error when no updatable field sent" do
        template = create(:checklist_template, position: 0)
        result = rpc("tools/call", { name: "update_habit", arguments: { id: template.id } })["result"]
        expect(result["isError"]).to be(true)
      end

      it "archive_habit hides from list_habits" do
        kept = create(:checklist_template, label: "Drink water", position: 0)
        old  = create(:checklist_template, label: "Old", position: 1)

        rpc("tools/call", { name: "archive_habit", arguments: { id: old.id } })

        result = rpc("tools/call", { name: "list_habits", arguments: {} })["result"]
        labels = JSON.parse(result["content"].first["text"])["habits"].map { |h| h["label"] }
        expect(labels).to contain_exactly("Drink water")
      end
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
