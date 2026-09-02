require "rails_helper"

RSpec.describe "MenuController#show", type: :request do
  let(:plan) { seed_plan(slug: "active") }
  let(:other_plan) { seed_plan(slug: "exercise", target_kcal: 2200) }
  let(:breakfast) do
    plan.meals.create!(position: 1, name: "Breakfast",
                       scheduled_time: Time.utc(2000, 1, 1, 7, 0),
                       target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10)
  end

  before { sign_in_as(create(:user, password: "password12345", food_tracking_enabled: true)) }

  it_behaves_like "food-gated page" do
    let(:make_request) { -> { get menu_path } }
  end

  describe "Log same as yesterday button visibility" do
    it "shows when yesterday matches plan and has more completions than today" do
      yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
      yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)

      get menu_path
      expect(Capybara.string(response.body)).to have_button("Log same as yesterday")
    end

    it "hides when yesterday's plan differs from today's" do
      other_plan
      yesterday = DailyLog.create!(date: Date.current - 1, plan: other_plan)
      yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)
      DailyLog.today

      get menu_path
      expect(Capybara.string(response.body)).not_to have_button("Log same as yesterday")
    end

    it "hides when there is no yesterday log" do
      plan
      DailyLog.where(date: Date.current - 1).destroy_all

      get menu_path
      expect(Capybara.string(response.body)).not_to have_button("Log same as yesterday")
    end

    it "hides when yesterday has zero completions" do
      DailyLog.create!(date: Date.current - 1, plan: plan)

      get menu_path
      expect(Capybara.string(response.body)).not_to have_button("Log same as yesterday")
    end

    it "hides when today already has equal-or-more completions than yesterday" do
      yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
      yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)
      DailyLog.today.meal_completions.create!(meal: breakfast, completed_at: Time.current)

      get menu_path
      expect(Capybara.string(response.body)).not_to have_button("Log same as yesterday")
    end
  end

  describe "cross-tenant isolation" do
    it "does not show another user's plans in the switcher" do
      user_a = create(:user, password: "password12345")
      sign_in_as(user_a)
      create(:plan, slug: "active", name: "A active", user: user_a)
      create(:plan, slug: "rest", name: "OTHER MENU PLAN", user: create(:user))

      get menu_path

      expect(response.body).not_to include("OTHER MENU PLAN")
    end
  end
end
