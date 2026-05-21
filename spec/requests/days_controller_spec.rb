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

    it "renders the inline quantity edit form for each existing logged food" do
      past = DailyLog.create!(date: past_date, plan: plan)
      past.logged_foods.create!(food: food, quantity_grams: 75, logged_at: past_date.to_time)

      get day_path(past_date)

      expect(response.body).to include('name="logged_food[quantity_grams]"')
      expect(response.body).to include('data-controller="auto-submit"')
      expect(response.body).to match(/data-action="blur-(>|&gt;)auto-submit#submit"/)
    end
  end
end
