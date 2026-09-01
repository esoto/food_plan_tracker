require "rails_helper"

RSpec.describe MealsController, type: :request do
  let(:plan) { create(:plan, user: Current.user) }
  let(:meal) do
    plan.meals.create!(
      user: Current.user, position: 1, name: "Breakfast",
      scheduled_time: Time.utc(2000, 1, 1, 7, 0),
      target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10
    )
  end

  before { sign_in_as(create(:user, password: "password12345", food_tracking_enabled: true)) }

  it_behaves_like "food-gated page" do
    let(:make_request) { -> { patch meal_path(meal), params: { meal: { name: "First feeding" } } } }
  end

  describe "PATCH /meals/:id" do
    it "updates name + macros and redirects 303" do
      patch meal_path(meal),
            params: { meal: { name: "First feeding", target_kcal: 450 } }
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(settings_path)
      expect(meal.reload.name).to eq("First feeding")
      expect(meal.target_kcal).to eq(450)
    end

    it "coerces HH:MM scheduled_time into a UTC sentinel" do
      patch meal_path(meal),
            params: { meal: { scheduled_time: "07:30" } }
      expect(meal.reload.scheduled_time.utc.strftime("%H:%M")).to eq("07:30")
      expect(meal.scheduled_time.utc.year).to eq(2000)
    end

    it "redirects with alert on invalid params" do
      patch meal_path(meal),
            params: { meal: { name: "" } }
      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to be_present
      expect(meal.reload.name).to eq("Breakfast")
    end
  end

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }

    it "PATCH another user's meal returns 404 and does not mutate it" do
      b_plan = create(:plan, user: user_b)
      b_meal = b_plan.meals.create!(
        user: user_b, position: 1, name: "Original",
        scheduled_time: Time.utc(2000, 1, 1, 7, 0),
        target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10
      )
      patch meal_path(b_meal), params: { meal: { name: "Hacked" } }

      expect(response).to have_http_status(:not_found)
      # Load-bearing: even if a future change adds a rescue_from that turns
      # RecordNotFound into a 200, the foreign record must not be mutated.
      expect(b_meal.reload.name).to eq("Original")
    end
  end
end
