require "rails_helper"

RSpec.describe ExchangesController, type: :request do
  before do
    sign_in_as
    @chicken    = Food.create!(name: "Chicken breast", category: :protein,  serving_grams: 100, kcal: 165, protein_g: 31, carbs_g: 0,  fat_g: 4)
    @rice       = Food.create!(name: "White rice",     category: :carb,     serving_grams: 100, kcal: 130, protein_g: 3,  carbs_g: 28, fat_g: 0)
    @almonds    = Food.create!(name: "Almonds",        category: :fat,      serving_grams: 28,  kcal: 164, protein_g: 6,  carbs_g: 6,  fat_g: 14)
    @broccoli   = Food.create!(name: "Broccoli",       category: :vegetable, serving_grams: 100, kcal: 35,  protein_g: 3,  carbs_g: 7,  fat_g: 0)
  end

  describe "GET /exchanges" do
    it "defaults to the protein category when no category param is provided" do
      get exchanges_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(@chicken.name)
      expect(response.body).not_to include(@rice.name)
    end

    it "filters by a valid category param" do
      get exchanges_path, params: { category: "carb" }
      expect(response.body).to include(@rice.name)
      expect(response.body).not_to include(@chicken.name)
    end

    it "falls back to protein when given an invalid category param (defense against arbitrary method calls)" do
      get exchanges_path, params: { category: "destroy_all" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(@chicken.name)
    end

    it "filters by a search query within the active category" do
      get exchanges_path, params: { category: "protein", q: "chicken" }
      expect(response.body).to include(@chicken.name)
    end

    it "matches case-insensitively (ILIKE)" do
      get exchanges_path, params: { category: "protein", q: "CHICKEN" }
      expect(response.body).to include(@chicken.name)
    end
  end

  describe "cross-tenant isolation on daily_log_id" do
    it "ignores a daily_log_id belonging to another user" do
      user_a = create(:user, password: "password")
      sign_in_as(user_a)
      other  = create(:user)
      plan_b = create(:plan, user: other)
      log_b  = create(:daily_log, user: other, plan: plan_b)

      get exchanges_path, params: { daily_log_id: log_b.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("daily_log_id=#{log_b.id}")
    end
  end
end
