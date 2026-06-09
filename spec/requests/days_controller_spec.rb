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

    describe "weight goal scoping for past dates" do
      it "displays only the current user's weight goal, not another user's (PER-570)" do
        # Create user_b's weight goal FIRST with distinctive target (foreign record comes first)
        user_b = create(:user)
        foreign_weight_goal = create(:goal, :weight, target_value: 987.5, user: user_b)

        # Create current user and their weight goal
        user_a = create(:user, password: "password")
        user_a_plan = seed_plan(slug: "active", user: user_a)
        own_weight_goal = create(:goal, :weight, target_value: 65.0, user: user_a)

        sign_in_as(user_a)

        past = DailyLog.create!(date: past_date, plan: user_a_plan, user: user_a)

        get day_path(past_date)

        expect(response).to have_http_status(:ok)
        # Own goal's target value should be visible (exact partial output)
        expect(response.body).to include("Goal: 65.0 kg")
        # Foreign goal's target value should NOT be visible
        expect(response.body).not_to include("987.5")
        # Own goal id should be in the hidden field
        expect(response.body).to include(%Q(value="#{own_weight_goal.id}"))
        # Foreign goal id should NOT be in the hidden field
        expect(response.body).not_to include(%Q(value="#{foreign_weight_goal.id}"))
      end
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
