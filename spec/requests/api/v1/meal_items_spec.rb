require "rails_helper"

RSpec.describe "Api::V1::MealItems", type: :request do
  before { stub_api_token }

  let(:plan)  { create(:plan) }
  let(:meal)  { create(:meal, plan: plan, name: "Breakfast") }
  let(:eggs)  { create(:food, name: "Eggs",       category: "protein", serving_grams: 50, kcal: 78, protein_g: 6, carbs_g: 0.5, fat_g: 5) }
  let(:oats)  { create(:food, name: "Oats",       category: "carb",    serving_grams: 40, kcal: 150, protein_g: 5, carbs_g: 27, fat_g: 3) }
  let(:evoo)  { create(:food, name: "EVOO",       category: "fat",     serving_grams: 14, kcal: 120, protein_g: 0, carbs_g: 0, fat_g: 14) }

  describe "GET /api/v1/meals/:meal_id/items" do
    it "lists items with computed kcal/macros" do
      create(:meal_item, meal: meal, food: eggs, quantity_grams: 100)
      create(:meal_item, meal: meal, food: oats, quantity_grams: 40)

      get "/api/v1/meals/#{meal.id}/items", headers: auth_headers

      expect(response).to have_http_status(:ok)
      items = response.parsed_body["meal_items"]
      expect(items.size).to eq(2)
      expect(items.first.keys).to include("id", "food_id", "food_name", "category", "quantity_grams", "kcal", "protein_g", "carbs_g", "fat_g")
    end
  end

  describe "POST /api/v1/meals/:meal_id/items" do
    it "creates an item and returns the recomputed totals" do
      expect {
        post "/api/v1/meals/#{meal.id}/items",
             params: { meal_item: { food_id: eggs.id, quantity_grams: 150 } }.to_json,
             headers: auth_headers
      }.to change(MealItem, :count).by(1)

      expect(response).to have_http_status(:created)
      item = response.parsed_body["meal_item"]
      expect(item["food_name"]).to eq("Eggs")
      expect(item["quantity_grams"]).to eq(150.0)
      expect(item["kcal"]).to eq(234) # 78 * (150/50)
    end

    it "422s with non-positive quantity_grams" do
      post "/api/v1/meals/#{meal.id}/items",
           params: { meal_item: { food_id: eggs.id, quantity_grams: 0 } }.to_json,
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "404s when the meal id doesn't exist" do
      post "/api/v1/meals/999999/items",
           params: { meal_item: { food_id: eggs.id, quantity_grams: 100 } }.to_json,
           headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/meal_items/:id" do
    it "updates quantity_grams and recomputes macros" do
      item = create(:meal_item, meal: meal, food: eggs, quantity_grams: 150)

      patch "/api/v1/meal_items/#{item.id}",
            params: { meal_item: { quantity_grams: 100 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["meal_item"]["kcal"]).to eq(156) # 78 * (100/50)
      expect(item.reload.quantity_grams.to_f).to eq(100.0)
    end

    it "ignores food_id changes (whitelist enforcement)" do
      item = create(:meal_item, meal: meal, food: eggs, quantity_grams: 150)
      patch "/api/v1/meal_items/#{item.id}",
            params: { meal_item: { food_id: oats.id, quantity_grams: 100 } }.to_json,
            headers: auth_headers

      expect(item.reload.food_id).to eq(eggs.id)
    end
  end

  describe "DELETE /api/v1/meal_items/:id" do
    it "removes the item" do
      item = create(:meal_item, meal: meal, food: evoo, quantity_grams: 14)
      expect {
        delete "/api/v1/meal_items/#{item.id}", headers: auth_headers
      }.to change(MealItem, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ "removed" => true, "id" => item.id })
    end
  end
end
