require "rails_helper"

RSpec.describe LoggedFoodsController, type: :request do
  let!(:user) { create(:user, food_tracking_enabled: true) }
  let!(:plan) { seed_plan(slug: "active", user: user) }
  let!(:food) { seed_food(name: "Whole eggs", category: "protein", serving_grams: 50, kcal: 78, protein_g: 6, carbs_g: 1, fat_g: 5) }

  before { sign_in_as(user) }

  it_behaves_like "food-gated page" do
    let(:make_request) { -> { post logged_foods_path, params: { food_id: food.id, quantity_grams: 100 } } }
  end

  describe "POST /logged_foods" do
    it "logs the food onto today by default" do
      expect {
        post logged_foods_path, params: { food_id: food.id, quantity_grams: 100 }
      }.to change { DailyLog.today.logged_foods.count }.from(0).to(1)
    end

    it "logs onto a past day when daily_log_id is provided" do
      past = DailyLog.create!(date: Date.current - 3, plan: plan)

      expect {
        post logged_foods_path, params: { food_id: food.id, quantity_grams: 80, daily_log_id: past.id }
      }.to change { past.logged_foods.count }.from(0).to(1)

      expect(DailyLog.today.logged_foods.count).to eq(0)
      expect(response).to redirect_to(day_path(past.date))
    end

    it "redirects today's create back to root" do
      post logged_foods_path, params: { food_id: food.id, quantity_grams: 100 }
      expect(response).to redirect_to(root_path)
    end

    describe "daily_log_from_params cross-tenant (PER-556 helper)" do
      it "returns 404 when daily_log_id belongs to another user" do
        user_a = create(:user, password: "password12345", food_tracking_enabled: true)
        sign_in_as(user_a)
        other  = create(:user)
        plan_b = create(:plan, user: other)
        log_b  = create(:daily_log, user: other, plan: plan_b)
        food   = create(:food)

        post logged_foods_path, params: { daily_log_id: log_b.id, food_id: food.id, quantity_grams: 100 }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /logged_foods/:id" do
    it "updates the quantity_grams" do
      log = DailyLog.today
      entry = log.logged_foods.create!(food: food, quantity_grams: 50, logged_at: Time.current)

      patch logged_food_path(entry), params: { logged_food: { quantity_grams: 120 } }

      expect(entry.reload.quantity_grams.to_i).to eq(120)
      expect(response).to redirect_to(root_path)
    end

    it "redirects back to /days/:date when editing a past-day entry" do
      past = DailyLog.create!(date: Date.current - 2, plan: plan)
      entry = past.logged_foods.create!(food: food, quantity_grams: 50, logged_at: 2.days.ago)

      patch logged_food_path(entry), params: { logged_food: { quantity_grams: 75 } }

      expect(entry.reload.quantity_grams.to_i).to eq(75)
      expect(response).to redirect_to(day_path(past.date))
    end

    it "redirects with an alert when quantity_grams is blank (no 500)" do
      log = DailyLog.today
      entry = log.logged_foods.create!(food: food, quantity_grams: 50, logged_at: Time.current)

      patch logged_food_path(entry), params: { logged_food: { quantity_grams: "" } }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/Quantity/)
      expect(entry.reload.quantity_grams.to_i).to eq(50)
    end

    it "redirects with an alert when quantity_grams is zero" do
      log = DailyLog.today
      entry = log.logged_foods.create!(food: food, quantity_grams: 50, logged_at: Time.current)

      patch logged_food_path(entry), params: { logged_food: { quantity_grams: 0 } }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/Quantity/)
      expect(entry.reload.quantity_grams.to_i).to eq(50)
    end
  end

  describe "DELETE /logged_foods/:id" do
    it "removes a today entry and redirects to root" do
      entry = DailyLog.today.logged_foods.create!(food: food, quantity_grams: 50, logged_at: Time.current)

      expect {
        delete logged_food_path(entry)
      }.to change(LoggedFood, :count).by(-1)

      expect(response).to redirect_to(root_path)
    end

    it "removes a past-day entry and redirects back to /days/:date" do
      past = DailyLog.create!(date: Date.current - 4, plan: plan)
      entry = past.logged_foods.create!(food: food, quantity_grams: 50, logged_at: 4.days.ago)

      delete logged_food_path(entry)

      expect(LoggedFood.where(id: entry.id)).to be_empty
      expect(response).to redirect_to(day_path(past.date))
    end

    it "returns 404 and preserves another user's logged_food (cross-tenant destroy)" do
      user_b = create(:user)
      plan_b = create(:plan, user: user_b)
      log_b  = create(:daily_log, user: user_b, plan: plan_b, date: Date.current)
      food_b = create(:food)
      entry = create(:logged_food, daily_log: log_b, food: food_b, user: user_b,
                                   quantity_grams: 50, logged_at: Time.current)

      expect {
        delete logged_food_path(entry)
      }.not_to change(LoggedFood, :count)

      expect(response).to have_http_status(:not_found)
      expect(entry.reload).to be_persisted
    end
  end

  describe "PATCH /logged_foods/:id cross-tenant" do
    it "returns 404 and preserves another user's logged_food quantity" do
      user_b = create(:user)
      plan_b = create(:plan, user: user_b)
      log_b  = create(:daily_log, user: user_b, plan: plan_b, date: Date.current)
      food_b = create(:food)
      entry = create(:logged_food, daily_log: log_b, food: food_b, user: user_b,
                                   quantity_grams: 50, logged_at: Time.current)

      patch logged_food_path(entry), params: { logged_food: { quantity_grams: 999 } }

      expect(response).to have_http_status(:not_found)
      expect(entry.reload.quantity_grams.to_i).to eq(50)
    end

    it "POSITIVE CONTROL: PATCH on the user's own past-day logged_food still works" do
      past = DailyLog.create!(date: Date.current - 2, plan: plan, user: user)
      entry = past.logged_foods.create!(food: food, user: user,
                                        quantity_grams: 50, logged_at: 2.days.ago)

      patch logged_food_path(entry), params: { logged_food: { quantity_grams: 175 } }

      expect(entry.reload.quantity_grams.to_i).to eq(175)
      expect(response).to redirect_to(day_path(past.date))
    end
  end
end
