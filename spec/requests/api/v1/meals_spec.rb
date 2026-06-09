require "rails_helper"

RSpec.describe "GET /api/v1/meals", type: :request do
  before do
    stub_api_token
    plan = seed_plan(slug: "active")
    @meal = plan.meals.find_or_create_by!(name: "Breakfast") do |m|
      m.scheduled_time = Time.utc(2000, 1, 1, 7, 0)
      m.position = 1
      m.target_kcal = 400
      m.target_protein_g = 30
      m.target_carbs_g = 50
      m.target_fat_g = 10
    end
  end

  it "returns meals for the requested plan" do
    get "/api/v1/meals?plan=active", headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["plan"]["slug"]).to eq("active")
    expect(body["meals"].first["name"]).to eq("Breakfast")
    expect(body["meals"].first).to have_key("time_of_day")
  end

  it "returns 404 for an unknown plan slug" do
    get "/api/v1/meals?plan=missing", headers: auth_headers
    expect(response).to have_http_status(:not_found)
  end

  it "denormalizes per-item macros and exposes a meal totals block" do
    @meal.meal_items.destroy_all # idempotent — Breakfast may have items from a previous example via find_or_create_by!
    egg = seed_food(name: "Egg", category: "protein", serving_grams: 100, kcal: 150, protein_g: 12, carbs_g: 0, fat_g: 10)
    rice = seed_food(name: "Rice", category: "carb", serving_grams: 100, kcal: 130, protein_g: 3, carbs_g: 28, fat_g: 0)
    @meal.meal_items.create!(food: egg,  quantity_grams: 200) # 2× serving → 300 kcal / 24 P / 0 C / 20 F
    @meal.meal_items.create!(food: rice, quantity_grams: 150) # 1.5×       → 195 kcal / 4.5 P / 42 C / 0 F

    get "/api/v1/meals?plan=active", headers: auth_headers

    meal = response.parsed_body["meals"].find { |m| m["name"] == "Breakfast" }
    expect(meal["items"].size).to eq(2)
    egg_item = meal["items"].find { |i| i["food_name"] == "Egg" }
    rice_item = meal["items"].find { |i| i["food_name"] == "Rice" }

    expect(egg_item).to include(
      "quantity_grams" => 200.0,
      "kcal" => 300,
      "protein_g" => 24.0,
      "carbs_g" => 0.0,
      "fat_g" => 20.0
    )
    expect(rice_item).to include(
      "kcal" => 195,
      "protein_g" => 4.5,
      "carbs_g" => 42.0,
      "fat_g" => 0.0
    )

    expect(meal["totals"]).to eq(
      "kcal" => 495,
      "protein_g" => 28.5,
      "carbs_g" => 42.0,
      "fat_g" => 20.0
    )
  end

  describe "cross-tenant isolation" do
    let(:user_a) { Current.user }
    let(:user_b) { create(:user) }

    it "resolves the authenticated user's plan when both users share a slug" do
      # Create user_b's plan FIRST so it has the lower id — if the controller
      # is unscoped, find_by! returns user_b's plan (load-bearing RED).
      b_plan = create(:plan, user: user_b, slug: "exercise", name: "B exercise")
      a_plan = create(:plan, user: user_a, slug: "exercise", name: "A exercise")

      get "/api/v1/meals?plan=exercise", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("plan", "id")).to eq(a_plan.id)
      expect(response.parsed_body.dig("plan", "id")).not_to eq(b_plan.id)
    end
  end
end
