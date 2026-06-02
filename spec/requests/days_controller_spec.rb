require "rails_helper"

RSpec.describe DaysController, type: :request do
  let!(:user) { create(:user) }
  let!(:plan) { seed_plan(slug: "active", user: user) }
  let!(:food) { seed_food(name: "Whole eggs", category: "protein", serving_grams: 50, kcal: 78, protein_g: 6, carbs_g: 1, fat_g: 5) }
  let(:past_date) { Date.current - 3 }

  before { sign_in_as(user) }

  describe "GET /days/:date" do
    it "redirects to root when the date is today" do
      get day_path(Date.current)
      expect(response).to redirect_to(root_path)
    end

    it "renders the '+ Log a food on this day' CTA scoped by daily_log_id" do
      past = DailyLog.create!(date: past_date, plan: plan)

      get day_path(past_date)

      expect(response.body).to include("Log a food on this day")
      expect(response.body).to include("/exchanges?daily_log_id=#{past.id}")
    end
  end

  describe "cross-tenant isolation" do
    it "does not show another user's plans" do
      user_a = create(:user, password: "password")
      sign_in_as(user_a)
      create(:plan, slug: "active", name: "A active", user: user_a)
      create(:plan, slug: "rest", name: "OTHER DAYS PLAN", user: create(:user))

      get day_path(Date.current - 2)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("OTHER DAYS PLAN")
    end
  end
end
