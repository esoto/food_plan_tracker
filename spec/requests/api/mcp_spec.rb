require "rails_helper"

RSpec.describe "POST /mcp", type: :request do
  let(:user)        { create(:user) }
  let(:application) { Doorkeeper::Application.create!(name: "Test Client", redirect_uri: "https://example.com/cb", scopes: "mcp", confidential: true) }
  let!(:token)      { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "mcp") }
  let(:plain_token) { token.plaintext_token }

  let(:auth) { { "Authorization" => "Bearer #{plain_token}", "Content-Type" => "application/json" } }

  before do
    Current.user = user
    seed_plan(slug: "active")
  end

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

  describe "malformed JSON body" do
    it "returns a JSON-RPC parse_error (400) when no Authorization header is present" do
      post "/mcp",
           params: "not-json-{[",
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:bad_request)
      body = response.parsed_body
      expect(body).to include("jsonrpc" => "2.0", "id" => nil)
      expect(body.dig("error", "code")).to eq(-32700)
      expect(body.dig("error", "message")).to eq("parse error")
    end

    it "returns a JSON-RPC parse_error (400) when the bearer is valid" do
      post "/mcp",
           params: "not-json-{[",
           headers: auth
      expect(response).to have_http_status(:bad_request)
      body = response.parsed_body
      expect(body).to include("jsonrpc" => "2.0", "id" => nil)
      expect(body.dig("error", "code")).to eq(-32700)
      expect(body.dig("error", "message")).to eq("parse error")
    end

    it "still rejects bogus bearers before parsing the body" do
      post "/mcp",
           params: "not-json-{[",
           headers: { "Authorization" => "Bearer wrong", "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
      # Lock in the auth-ordering invariant: Doorkeeper must short-circuit
      # before parse_message runs, so the parse-error envelope must NOT leak.
      if response.body.present?
        expect(response.parsed_body.dig("error", "code")).not_to eq(-32700)
      end
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
        "archive_habit", "restore_habit",
        "update_plan", "update_meal", "update_goal",
        "list_meal_items", "add_meal_item", "update_meal_item", "remove_meal_item"
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
      goal = Goal.find_or_create_by!(metric: Goal.metrics[:weight_kg], user: user) do |g|
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
      Goal.find_or_create_by!(metric: Goal.metrics[:weight_kg], user: user) do |g|
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
      log  = DailyLog.today(user: user)
      entry = log.logged_foods.create!(food: food, quantity_grams: 50, logged_at: Time.current)

      result = rpc("tools/call", { name: "delete_logged_food", arguments: { id: entry.id } })["result"]
      expect(result).not_to include("isError" => true)
      payload = JSON.parse(result["content"].first["text"])
      expect(payload["day"]["logged_foods"].map { |lf| lf["id"] }).not_to include(entry.id)
    end

    describe "logged_food cross-tenant isolation" do
      let(:other_user) { create(:user) }

      it "TC-LF1 delete_logged_food returns isError on other_user's entry and entry still exists" do
        other_food = seed_food(name: "Quinoa")
        other_plan = seed_plan(slug: "active", user: other_user)
        other_log  = DailyLog.today(user: other_user)
        other_entry = other_log.logged_foods.create!(food: other_food, quantity_grams: 100, logged_at: Time.current, user: other_user)

        result = rpc("tools/call", { name: "delete_logged_food", arguments: { id: other_entry.id } })["result"]
        expect(result["isError"]).to be(true)
        expect(LoggedFood.exists?(other_entry.id)).to be(true)
      end
    end

    describe "get_weekly_summary" do
      let!(:weight_goal) do
        Goal.find_or_create_by!(metric: Goal.metrics[:weight_kg], user: user) do |g|
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
        Plan.active(user: user).meals.create!(
          position: 1, name: "Breakfast",
          scheduled_time: Time.utc(2000, 1, 1, 7, 0),
          target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10,
          user: user
        )
      end

      it "copies yesterday's completions onto today and reports the count" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          plan = Plan.active(user: user)
          yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
          yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)

          result = rpc("tools/call", { name: "copy_yesterday_meals", arguments: {} })["result"]
          payload = JSON.parse(result["content"].first["text"])

          expect(payload["copied"]).to eq(1)
          expect(DailyLog.today(user: user).meal_completions.count).to eq(1)
        end
      end

      it "is idempotent — re-invocation reports copied: 0 and preserves prior completions" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          plan = Plan.active(user: user)
          yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
          yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)

          rpc("tools/call", { name: "copy_yesterday_meals", arguments: {} })
          first_completion = DailyLog.today(user: user).meal_completions.find_by!(meal: breakfast)
          first_timestamp = first_completion.completed_at

          result = rpc("tools/call", { name: "copy_yesterday_meals", arguments: {} })["result"]
          payload = JSON.parse(result["content"].first["text"])

          expect(payload["copied"]).to eq(0)
          expect(DailyLog.today(user: user).meal_completions.count).to eq(1)
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
          DailyLog.today(user: user)

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

      it "TC-CY1 copy_yesterday_meals returns isError when other_user has yesterday but I don't" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          other_user = create(:user)
          other_plan = seed_plan(slug: "active", user: other_user)
          other_yesterday = DailyLog.create!(date: Date.current - 1, plan: other_plan, user: other_user)

          result = rpc("tools/call", { name: "copy_yesterday_meals", arguments: {} })["result"]
          expect(result["isError"]).to be(true)
          expect(result["content"].first["text"]).to match(/no_yesterday_log/)
        end
      end
    end

    describe "supplements management" do
      let(:other_user) { create(:user) }

      it "list_supplements returns kept supplements with their time slots" do
        sup = create(:supplement, name: "Magnesium", user: user)
        sup.supplement_schedules.create!(time_slot: "pre_sleep", position: 0)
        create(:supplement, name: "Archived stack", user: user, discarded_at: 1.day.ago)

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
        sup = create(:supplement, user: user)
        result = rpc("tools/call", { name: "update_supplement", arguments: { id: sup.id } })["result"]
        expect(result["isError"]).to be(true)
      end

      it "archive_supplement and restore_supplement round-trip" do
        sup = create(:supplement, user: user)

        rpc("tools/call", { name: "archive_supplement", arguments: { id: sup.id } })
        expect(sup.reload.discarded_at).to be_present

        rpc("tools/call", { name: "restore_supplement", arguments: { id: sup.id } })
        expect(sup.reload.discarded_at).to be_nil
      end

      # TC-S1: list own-only — both inclusion and exclusion asserted
      it "TC-S1 list_supplements includes own and excludes other_user's supplements" do
        # other_user's supplement MUST be created first (unscoped query would return first row)
        other_sup = create(:supplement, name: "Theirs", user: other_user)
        my_sup    = create(:supplement, name: "Mine", user: user)

        result = rpc("tools/call", { name: "list_supplements", arguments: {} })["result"]
        payload = JSON.parse(result["content"].first["text"])
        names = payload["supplements"].map { |s| s["name"] }
        expect(names).to include("Mine")
        expect(names).not_to include("Theirs")
      end

      # TC-S2: archived list variant
      it "TC-S2 list_supplements archived=true includes own archived, excludes other_user's" do
        other_sup = create(:supplement, name: "Theirs Archived", user: other_user, discarded_at: 1.day.ago)
        my_sup    = create(:supplement, name: "Mine Archived", user: user, discarded_at: 1.day.ago)

        result = rpc("tools/call", { name: "list_supplements", arguments: { archived: true } })["result"]
        payload = JSON.parse(result["content"].first["text"])
        names = payload["supplements"].map { |s| s["name"] }
        expect(names).to include("Mine Archived")
        expect(names).not_to include("Theirs Archived")
      end

      # TC-S3: update on other_user's supplement -> isError + reload unchanged
      it "TC-S3 update_supplement returns isError on other_user's id and leaves record unchanged" do
        other_sup = create(:supplement, name: "Original", user: other_user)

        result = rpc("tools/call", { name: "update_supplement",
                                     arguments: { id: other_sup.id, name: "Hacked" } })["result"]
        expect(result["isError"]).to be(true)
        expect(other_sup.reload.name).to eq("Original")
      end

      # TC-S4: archive on other_user's supplement -> isError + discarded_at nil
      it "TC-S4 archive_supplement returns isError on other_user's id and leaves record unarchived" do
        other_sup = create(:supplement, name: "Not Mine", user: other_user)

        result = rpc("tools/call", { name: "archive_supplement",
                                     arguments: { id: other_sup.id } })["result"]
        expect(result["isError"]).to be(true)
        expect(other_sup.reload.discarded_at).to be_nil
      end

      # TC-S5: restore on other_user's supplement -> isError + discarded_at still present
      it "TC-S5 restore_supplement returns isError on other_user's id and leaves record discarded" do
        other_sup = create(:supplement, name: "Not Mine Archived", user: other_user, discarded_at: 1.day.ago)

        result = rpc("tools/call", { name: "restore_supplement",
                                     arguments: { id: other_sup.id } })["result"]
        expect(result["isError"]).to be(true)
        expect(other_sup.reload.discarded_at).to be_present
      end

      # TC-S6: create assigns correct user (orphan lock)
      it "TC-S6 create_supplement assigns the authenticated user as owner" do
        result = rpc("tools/call", { name: "create_supplement",
                                     arguments: { name: "New Sup", dose: "1 capsule" } })["result"]
        expect(result).not_to include("isError" => true)
        payload = JSON.parse(result["content"].first["text"])
        created = Supplement.find(payload["supplement"]["id"])
        expect(created.user).to eq(user)
      end
    end

    describe "habits management" do
      before { Habit.delete_all }

      let(:other_user) { create(:user) }

      it "create_habit appends at the end of the position list" do
        create(:habit, label: "First", position: 0, user: user)

        result = rpc("tools/call", { name: "create_habit", arguments: { label: "Second" } })["result"]
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["habit"]["position"]).to eq(1)
      end

      it "update_habit is an error when no updatable field sent" do
        habit = create(:habit, position: 0, user: user)
        result = rpc("tools/call", { name: "update_habit", arguments: { id: habit.id } })["result"]
        expect(result["isError"]).to be(true)
      end

      it "create_habit with a blank kind returns isError and creates nothing (not a 500)" do
        result = rpc("tools/call", { name: "create_habit", arguments: { label: "Blank kind", kind: "" } })["result"]
        expect(result["isError"]).to be(true)
        expect(Habit.where(label: "Blank kind")).not_to exist
      end

      it "create_habit with kind quantity works and list_habits shows it" do
        result = rpc("tools/call", { name: "create_habit",
                                     arguments: { label: "Water", kind: "quantity", unit: "glasses", target_value: 8 } })["result"]
        created = JSON.parse(result["content"].first["text"])["habit"]
        expect(created["kind"]).to eq("quantity")
        expect(created["unit"]).to eq("glasses")

        list_result = rpc("tools/call", { name: "list_habits", arguments: {} })["result"]
        listed = JSON.parse(list_result["content"].first["text"])["habits"].find { |h| h["label"] == "Water" }
        expect(listed["kind"]).to eq("quantity")
      end

      it "update_habit ignores a kind param — kind is immutable after creation" do
        habit = create(:habit, :quantity, label: "Water", position: 0, user: user)

        result = rpc("tools/call", { name: "update_habit",
                                     arguments: { id: habit.id, label: "Water intake", kind: "duration" } })["result"]
        updated = JSON.parse(result["content"].first["text"])["habit"]
        expect(updated["label"]).to eq("Water intake")
        expect(updated["kind"]).to eq("quantity")
        expect(habit.reload.kind).to eq("quantity")
      end

      it "archive_habit hides from list_habits" do
        kept = create(:habit, label: "Drink water", position: 0, user: user)
        old  = create(:habit, label: "Old", position: 1, user: user)

        rpc("tools/call", { name: "archive_habit", arguments: { id: old.id } })

        result = rpc("tools/call", { name: "list_habits", arguments: {} })["result"]
        labels = JSON.parse(result["content"].first["text"])["habits"].map { |h| h["label"] }
        expect(labels).to contain_exactly("Drink water")
      end

      # TC-H1: list own-only — both inclusion and exclusion asserted
      it "TC-H1 list_habits includes own and excludes other_user's habits" do
        # other_user's habit MUST be created first (unscoped query would return first row)
        other_habit = create(:habit, label: "Theirs", position: 0, user: other_user)
        my_habit    = create(:habit, label: "Mine", position: 0, user: user)

        result = rpc("tools/call", { name: "list_habits", arguments: {} })["result"]
        payload = JSON.parse(result["content"].first["text"])
        labels = payload["habits"].map { |h| h["label"] }
        expect(labels).to include("Mine")
        expect(labels).not_to include("Theirs")
      end

      # TC-H2: archived list variant
      it "TC-H2 list_habits archived=true includes own archived, excludes other_user's" do
        other_habit = create(:habit, label: "Theirs Archived", position: 0, user: other_user, discarded_at: 1.day.ago)
        my_habit    = create(:habit, label: "Mine Archived", position: 0, user: user, discarded_at: 1.day.ago)

        result = rpc("tools/call", { name: "list_habits", arguments: { archived: true } })["result"]
        payload = JSON.parse(result["content"].first["text"])
        labels = payload["habits"].map { |h| h["label"] }
        expect(labels).to include("Mine Archived")
        expect(labels).not_to include("Theirs Archived")
      end

      # TC-H3: update on other_user's habit -> isError + reload unchanged
      it "TC-H3 update_habit returns isError on other_user's id and leaves record unchanged" do
        other_habit = create(:habit, label: "Original", position: 0, user: other_user)

        result = rpc("tools/call", { name: "update_habit",
                                     arguments: { id: other_habit.id, label: "Hacked" } })["result"]
        expect(result["isError"]).to be(true)
        expect(other_habit.reload.label).to eq("Original")
      end

      # TC-H4: archive on other_user's habit -> isError + discarded_at nil
      it "TC-H4 archive_habit returns isError on other_user's id and leaves record unarchived" do
        other_habit = create(:habit, label: "Not Mine", position: 0, user: other_user)

        result = rpc("tools/call", { name: "archive_habit",
                                     arguments: { id: other_habit.id } })["result"]
        expect(result["isError"]).to be(true)
        expect(other_habit.reload.discarded_at).to be_nil
      end

      # TC-H5: restore on other_user's habit -> isError + discarded_at still present
      it "TC-H5 restore_habit returns isError on other_user's id and leaves record discarded" do
        other_habit = create(:habit, label: "Not Mine Archived", position: 0, user: other_user, discarded_at: 1.day.ago)

        result = rpc("tools/call", { name: "restore_habit",
                                     arguments: { id: other_habit.id } })["result"]
        expect(result["isError"]).to be(true)
        expect(other_habit.reload.discarded_at).to be_present
      end

      # TC-H6: next_position trap test — other_user's high position doesn't affect my new position
      it "TC-H6 next_position ignores other_user's habits (position not influenced by foreign high position)" do
        # Seed other_user with a high-position habit
        other_habit = create(:habit, label: "Their High", position: 999, user: other_user)
        # My existing habit
        my_habit    = create(:habit, label: "Mine", position: 0, user: user)

        result = rpc("tools/call", { name: "create_habit", arguments: { label: "My New" } })["result"]
        payload = JSON.parse(result["content"].first["text"])
        # New position should be 1 (based on MY max 0), not 1000 (based on GLOBAL max 999)
        expect(payload["habit"]["position"]).to eq(1)
      end

      # TC-H7: positive control — update_habit success (currently untested happy path)
      it "TC-H7 update_habit success updates label and returns updated record" do
        habit = create(:habit, label: "Original", position: 0, user: user)

        result = rpc("tools/call", { name: "update_habit",
                                     arguments: { id: habit.id, label: "Updated" } })["result"]
        expect(result).not_to include("isError" => true)
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["habit"]["label"]).to eq("Updated")
        expect(habit.reload.label).to eq("Updated")
      end

      # TC-H8: positive control — restore_habit success (currently untested happy path)
      it "TC-H8 restore_habit success restores and appends at position end" do
        # Create my archived habit and my kept habit
        archived = create(:habit, label: "Archived", position: 0, user: user, discarded_at: 1.day.ago)
        kept     = create(:habit, label: "Kept", position: 0, user: user)

        result = rpc("tools/call", { name: "restore_habit",
                                     arguments: { id: archived.id } })["result"]
        expect(result).not_to include("isError" => true)
        payload = JSON.parse(result["content"].first["text"])
        # After restore, position should be 1 (max of kept habits before restore)
        expect(payload["habit"]["position"]).to eq(1)
        expect(archived.reload.discarded_at).to be_nil
      end
    end

    describe "settings management" do
      let(:other_user) { create(:user) }

      it "update_plan updates macro targets by slug" do
        plan = create(:plan, slug: "exercise-test", target_kcal: 2000, user: user)
        result = rpc("tools/call", {
          name: "update_plan",
          arguments: { slug: "exercise-test", target_kcal: 2300 }
        })["result"]
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["plan"]["target_kcal"]).to eq(2300)
        expect(plan.reload.target_kcal).to eq(2300)
      end

      it "update_plan returns isError when no updatable fields are sent" do
        create(:plan, slug: "active-only-slug", user: user)
        result = rpc("tools/call", { name: "update_plan", arguments: { slug: "active-only-slug" } })["result"]
        expect(result["isError"]).to be(true)
      end

      it "update_meal returns isError when no updatable fields are sent" do
        plan = create(:plan, slug: "exercise-only-slug", user: user)
        create(:meal, plan: plan, name: "OnlyMeal", user: user)
        result = rpc("tools/call", { name: "update_meal",
                                     arguments: { plan_slug: "exercise-only-slug", name: "OnlyMeal" } })["result"]
        expect(result["isError"]).to be(true)
      end

      it "update_plan returns isError on unknown slug" do
        result = rpc("tools/call", {
          name: "update_plan",
          arguments: { slug: "nope", target_kcal: 2300 }
        })["result"]
        expect(result["isError"]).to be(true)
      end

      it "update_meal updates macros and scheduled_time by plan_slug + name" do
        plan = create(:plan, slug: "active-test", user: user)
        meal = create(:meal, plan: plan, name: "Lunch", target_kcal: 500,
                      scheduled_time: Time.utc(2000, 1, 1, 12, 0), user: user)
        result = rpc("tools/call", {
          name: "update_meal",
          arguments: { plan_slug: "active-test", name: "Lunch",
                       target_kcal: 600, scheduled_time: "13:30" }
        })["result"]
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["meal"]["target_kcal"]).to eq(600)

        meal.reload
        expect(meal.target_kcal).to eq(600)
        expect(meal.scheduled_time.utc.strftime("%H:%M")).to eq("13:30")
      end

      it "update_meal returns isError when the meal name is unknown on the plan" do
        create(:plan, slug: "active-test2", user: user)
        result = rpc("tools/call", {
          name: "update_meal",
          arguments: { plan_slug: "active-test2", name: "Brunch", target_kcal: 100 }
        })["result"]
        expect(result["isError"]).to be(true)
      end

      it "update_goal updates target_value by metric" do
        goal = create(:goal, :weight, target_value: 80, user: user)
        result = rpc("tools/call", {
          name: "update_goal",
          arguments: { metric: "weight_kg", target_value: 78 }
        })["result"]
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["goal"]["target_value"]).to eq(78.0)
        expect(goal.reload.target_value.to_f).to eq(78.0)
      end

      it "update_goal returns isError on unknown metric" do
        result = rpc("tools/call", {
          name: "update_goal",
          arguments: { metric: "bogus_metric", target_value: 78 }
        })["result"]
        expect(result["isError"]).to be(true)
      end

      # TC-G1: list_goals own-only — both inclusion and exclusion
      it "TC-G1 list_goals includes own and excludes other_user's goals" do
        other_goal = create(:goal, :weight, target_value: 75, user: other_user)
        my_goal    = create(:goal, :weight, target_value: 80, user: user)

        result = rpc("tools/call", { name: "list_goals", arguments: {} })["result"]
        payload = JSON.parse(result["content"].first["text"])
        goal_ids = payload["goals"].map { |g| g["id"] }
        expect(goal_ids).to include(my_goal.id)
        expect(goal_ids).not_to include(other_goal.id)
      end

      # TC-G2: log_weight scoped to Current.user's weight_kg goal
      it "TC-G2 log_weight uses Current.user's weight goal, not other_user's" do
        other_goal = create(:goal, :weight, target_value: 75, user: other_user)
        my_goal    = create(:goal, :weight, target_value: 80, user: user)

        result = rpc("tools/call", { name: "log_weight", arguments: { value: 78 } })["result"]
        expect(result).not_to include("isError" => true)
        payload = JSON.parse(result["content"].first["text"])
        # The entry should be linked to my_goal, not other_goal
        expect(payload["entry"]["value"]).to eq(78)
        expect(my_goal.reload.biomarker_entries.count).to eq(1)
        expect(other_goal.reload.biomarker_entries.count).to eq(0)
      end

      # TC-G3: update_goal on other_user's goal -> isError
      it "TC-G3 update_goal returns isError when other_user is the only owner of the metric" do
        other_goal = create(:goal, :weight, target_value: 75, user: other_user)

        result = rpc("tools/call", {
          name: "update_goal",
          arguments: { metric: "weight_kg", target_value: 70 }
        })["result"]
        expect(result["isError"]).to be(true)
        expect(other_goal.reload.target_value.to_f).to eq(75)
      end

      # TC-P1: update_plan — other_user's plan unchanged, my plan updated, returned plan is mine
      it "TC-P1 update_plan updates only my plan, not other_user's with same slug" do
        other_plan = create(:plan, slug: "active", target_kcal: 1800, user: other_user)
        my_plan    = Plan.active(user: user)

        result = rpc("tools/call", {
          name: "update_plan",
          arguments: { slug: "active", target_kcal: 2100 }
        })["result"]
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["plan"]["id"]).to eq(my_plan.id)
        expect(payload["plan"]["target_kcal"]).to eq(2100)
        expect(my_plan.reload.target_kcal).to eq(2100)
        expect(other_plan.reload.target_kcal).to eq(1800)
      end

      # TC-P2: set_plan_for_day with slug only other_user owns -> isError
      it "TC-P2 set_plan_for_day returns isError when slug belongs only to other_user" do
        other_plan = seed_plan(slug: "rest", user: other_user)

        result = rpc("tools/call", {
          name: "set_plan_for_day",
          arguments: { slug: "rest" }
        })["result"]
        expect(result["isError"]).to be(true)
        expect(result["content"].first["text"]).to match(/Couldn't find/)
      end

      # TC-WS1: weekly summary data isolation
      it "TC-WS1 get_weekly_summary excludes other_user's logs and biomarkers" do
        travel_to Time.zone.local(2026, 4, 25, 12, 0) do
          other_goal = create(:goal, :weight, target_value: 75, user: other_user)
          other_goal.biomarker_entries.create!(recorded_on: Date.current, value: 75.0)
          other_log  = DailyLog.create!(date: Date.current, plan: seed_plan(slug: "active", user: other_user), user: other_user)

          my_goal = create(:goal, :weight, target_value: 80, user: user)

          result = rpc("tools/call", { name: "get_weekly_summary", arguments: {} })["result"]
          payload = JSON.parse(result["content"].first["text"])
          # My empty logs should result in nil metrics, not contaminated by other_user's data
          expect(payload["weight_delta_kg"]).to be_nil
          expect(payload["adherence_pct"]).to be_nil
        end
      end
    end

    describe "meal item management" do
      let(:plan2) { create(:plan, slug: "exercise-mi", user: user) }
      let(:meal2) { create(:meal, plan: plan2, name: "Breakfast", user: user) }
      let(:eggs2) { create(:food, name: "Eggs", category: "protein", serving_grams: 50, kcal: 78, protein_g: 6, carbs_g: 0.5, fat_g: 5) }
      let(:oats2) { create(:food, name: "Oats", category: "carb",    serving_grams: 40, kcal: 150, protein_g: 5, carbs_g: 27, fat_g: 3) }

      it "list_meal_items returns items with computed macros" do
        create(:meal_item, meal: meal2, food: eggs2, quantity_grams: 100)

        result = rpc("tools/call", { name: "list_meal_items",
                                     arguments: { plan_slug: "exercise-mi", meal_name: "Breakfast" } })["result"]
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["meal_items"].size).to eq(1)
        expect(payload["meal_items"].first["food_name"]).to eq("Eggs")
        expect(payload["meal_items"].first["kcal"]).to eq(156)
      end

      it "update_meal_item changes quantity by meal+food name and returns recomputed macros" do
        item = create(:meal_item, meal: meal2, food: eggs2, quantity_grams: 150)

        result = rpc("tools/call", { name: "update_meal_item",
                                     arguments: { plan_slug: "exercise-mi", meal_name: "Breakfast",
                                                  food_name: "Eggs", quantity_grams: 100 } })["result"]
        payload = JSON.parse(result["content"].first["text"])
        expect(payload["meal_item"]["quantity_grams"]).to eq(100.0)
        expect(item.reload.quantity_grams.to_f).to eq(100.0)
      end

      it "add_meal_item attaches a food to a meal" do
        oats2 # ensure factory created
        expect {
          rpc("tools/call", { name: "add_meal_item",
                               arguments: { plan_slug: "exercise-mi", meal_name: "Breakfast",
                                            food_name: "Oats", quantity_grams: 40 } })
        }.to change { meal2.meal_items.count }.by(1)
      end

      it "remove_meal_item drops a food from a meal" do
        item = create(:meal_item, meal: meal2, food: eggs2, quantity_grams: 100)

        rpc("tools/call", { name: "remove_meal_item",
                             arguments: { plan_slug: "exercise-mi", meal_name: "Breakfast",
                                          food_name: "Eggs" } })

        expect(MealItem.exists?(item.id)).to be(false)
      end

      it "remove_meal_item returns isError when the food is not in the meal" do
        meal2  # ensure exists
        result = rpc("tools/call", { name: "remove_meal_item",
                                     arguments: { plan_slug: "exercise-mi", meal_name: "Breakfast",
                                                  food_name: "NotInMeal" } })["result"]
        expect(result["isError"]).to be(true)
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

    # TC-P3: plan_for helper scoped to Current.user
    describe "plan_for cross-tenant isolation" do
      let(:other_user) { create(:user) }

      it "list_meals returns isError when plan_slug belongs only to other_user" do
        # other_user's plan MUST be created first so an unscoped find_by would
        # return it instead of raising RecordNotFound
        seed_plan(slug: "rest", user: other_user)

        result = rpc("tools/call", { name: "list_meals", arguments: { plan_slug: "rest" } })["result"]
        expect(result["isError"]).to be(true)
        expect(result["content"].first["text"]).to match(/Couldn't find/)
      end

      it "add_meal_item returns isError when plan_slug belongs only to other_user" do
        other_plan = seed_plan(slug: "rest", user: other_user)
        create(:meal, plan: other_plan, name: "Dinner", user: other_user)
        seed_food(name: "Rice")

        result = rpc("tools/call", { name: "add_meal_item",
                                     arguments: { plan_slug: "rest", meal_name: "Dinner",
                                                  food_name: "Rice", quantity_grams: 100 } })["result"]
        expect(result["isError"]).to be(true)
        expect(result["content"].first["text"]).to match(/Couldn't find/)
      end
    end
  end
end
