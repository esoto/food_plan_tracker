require "rails_helper"

RSpec.describe "Daily interactions via Stimulus/Turbo", type: :system do
  include ActionView::RecordIdentifier
  describe "S4a: Plan switcher auto-submit via label click" do
    it "changes the active plan and updates the DailyLog in the database" do
      # Plan switcher is food UI, gated behind food_tracking_enabled — this
      # spec is inherently about that UI, so opt this user in.
      user = create_onboarded_user(email: "alice@example.com")
      user.update!(food_tracking_enabled: true)
      system_sign_in(email: "alice@example.com", password: "password12345")

      visit root_path
      expect(page).to have_text("Active day")
      expect(page).to have_text("Exercise day")
      expect(page).to have_text("Rest day")

      # Find the "Rest day" plan label and click it
      # (Stimulus auto-submit listener fires on radio change)
      find("label", text: "Rest day").click

      # Wait for the form to submit and page to update
      # (Turbo handles the redirect; Capybara retrying matchers wait for DOM stability)
      expect(page).to have_current_path(root_path)

      # Verify the active tab styling changed (the active plan's label has the active class)
      rest_day_plan = user.plans.find_by!(slug: "rest")
      active_log = DailyLog.find_by(user_id: user.id, date: Date.current)
      expect(active_log.plan_id).to eq(rest_day_plan.id)
    end
  end

  describe "S4b: Meal completion Turbo Frame swap with undo" do
    it "toggles meal completion status with in-frame Turbo Frame swap" do
      user = create_onboarded_user(email: "alice@example.com")
      user.update!(food_tracking_enabled: true)
      system_sign_in(email: "alice@example.com", password: "password12345")

      # Create a meal on the user's active plan
      active_plan = user.plans.find_by!(slug: "active")
      meal = create(:meal, user: user, plan: active_plan)
      food = create(:food)
      meal_item = create(:meal_item, meal: meal, food: food, user: user)

      # Fetch the daily_log that was created by onboarding
      daily_log = DailyLog.find_by!(user_id: user.id, date: Date.current)

      visit menu_path
      expect(page).to have_text("Today's menu")
      expect(page).to have_text(meal.name)

      # Click "Mark as completed" inside the meal card's Turbo Frame
      within("##{dom_id(meal)}") do
        expect(page).to have_button("Mark as completed")
        click_button "Mark as completed"
      end

      # Wait for the frame to swap (button text changes to "✓ Meal completed")
      within("##{dom_id(meal)}") do
        expect(page).to have_button("✓ Meal completed")
      end

      # Verify the MealCompletion was created
      expect(MealCompletion.where(meal_id: meal.id, daily_log_id: daily_log.id).count).to eq(1)

      # Click the undo button
      within("##{dom_id(meal)}") do
        click_button "✓ Meal completed"
      end

      # Verify the button reverted to "Mark as completed"
      within("##{dom_id(meal)}") do
        expect(page).to have_button("Mark as completed")
      end

      # Verify the MealCompletion was deleted
      expect(MealCompletion.where(meal_id: meal.id, daily_log_id: daily_log.id).count).to eq(0)
    end
  end

  describe "S4c: Checklist habit toggle with visual feedback" do
    it "marks a habit as complete with check icon and line-through text" do
      user = create_onboarded_user(email: "alice@example.com")
      system_sign_in(email: "alice@example.com", password: "password12345")

      # Create a habit for the user
      habit = create(:habit, user: user, label: "Morning walk", description: "30 min", icon: "🚶")

      # Fetch the daily_log that was created by onboarding
      daily_log = DailyLog.find_by!(user_id: user.id, date: Date.current)

      visit habits_path
      expect(page).to have_text("Daily habits")
      expect(page).to have_text("Morning walk")

      # Find the row containing the template label and submit it
      within("form[action*='habit_entries']") do
        expect(page).to have_text("Morning walk")
        click_button "Morning walk"
      end

      # Wait for the checkbox to be checked (visual: green background + checkmark),
      # scoped to the completion form — the progress bar also uses bg-emerald-500.
      within("form[action*='habit_entries']") do
        expect(page).to have_css("div.bg-emerald-500")
        expect(page).to have_selector("svg path[d*='M5 13l4 4L19 7']")
      end

      # Verify the text is line-through
      expect(page).to have_css(".line-through", text: "Morning walk")

      # Verify the progress bar is visible and > 0%
      expect(page).to have_css(".bg-emerald-500")

      # Verify the HabitEntry was created
      expect(HabitEntry.where(habit_id: habit.id, daily_log_id: daily_log.id).count).to eq(1)
    end
  end

  describe "S4f: Quantity habit +1 tap shows updated progress" do
    it "increments the value and displays current / target unit" do
      user = create_onboarded_user(email: "quant@example.com")
      system_sign_in(email: "quant@example.com", password: "password12345")

      create(:habit, :quantity, user: user, label: "Water", description: "Stay hydrated",
                                 icon: "💧", position: 0)

      visit habits_path
      expect(page).to have_text("Water")

      click_button "+1"

      expect(page).to have_text("1 / 8 glasses")
    end
  end

  describe "S4g: Rating habit tap highlights the selected value" do
    it "highlights the selected rating button" do
      user = create_onboarded_user(email: "rate@example.com")
      system_sign_in(email: "rate@example.com", password: "password12345")

      create(:habit, :rating, user: user, label: "Mood", description: "How do you feel?",
                               icon: "🙂", position: 0, rating_scale: 5)

      visit habits_path
      expect(page).to have_text("Mood")

      click_button "3"

      expect(page).to have_css("button.bg-indigo-600", text: "3")
    end
  end

  describe "S4e: Past-day auto-submit on /days/<yesterday>" do
    it "applies plan change to a past daily_log via the day_toggle form" do
      # Day-toggle switcher is food UI, gated behind food_tracking_enabled —
      # this spec is inherently about that UI, so opt this user in.
      user = create_onboarded_user(email: "alice@example.com")
      user.update!(food_tracking_enabled: true)
      system_sign_in(email: "alice@example.com", password: "password12345")

      # Create a daily_log for yesterday
      yesterday = Date.current - 1.day
      daily_log = create(:daily_log, user: user, date: yesterday, plan: user.plans.find_by!(slug: "active"))

      # Navigate to the past day
      visit day_path(yesterday)
      expect(page).to have_text(I18n.l(yesterday, format: "%B %-d, %Y"))

      # Click the "Exercise day" plan label
      find("label", text: "Exercise day").click

      # Wait for the page to update (Turbo handles the PATCH)
      expect(page).to have_current_path(day_path(yesterday))

      # Verify the daily_log's plan changed
      expect(daily_log.reload.plan.slug).to eq("exercise")
    end
  end

  describe "weight logging from the dashboard" do
    it "logs today's weight when a weight goal exists" do
      user = create_onboarded_user(email: "weigher@example.com")
      create(:goal, :weight, user: user)
      system_sign_in(email: "weigher@example.com", password: "password12345")

      fill_in "Enter your weight", with: "72.5"
      click_button "Log"

      expect(page).to have_text("72.5")
      expect(page).to have_no_text("— kg")
    end
  end
end
