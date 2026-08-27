require "rails_helper"

RSpec.describe WeeklySummary, type: :model do
  let(:user) { create(:user) }
  let!(:plan) do
    Plan.find_or_create_by!(slug: "active", user: user) do |p|
      p.name = "Active day"
      p.target_kcal = 2000
      p.target_protein_g = 180
      p.target_carbs_g = 180
      p.target_fat_g = 70
    end
  end
  let!(:other_plan) do
    Plan.find_or_create_by!(slug: "exercise", user: user) do |p|
      p.name = "Exercise day"
      p.target_kcal = 2200
      p.target_protein_g = 180
      p.target_carbs_g = 180
      p.target_fat_g = 70
    end
  end
  let!(:meal_a) { plan.meals.create!(position: 1, name: "A", scheduled_time: Time.utc(2000, 1, 1, 7, 0), target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10, user: user) }
  let!(:meal_b) { plan.meals.create!(position: 2, name: "B", scheduled_time: Time.utc(2000, 1, 1, 12, 0), target_kcal: 600, target_protein_g: 45, target_carbs_g: 60, target_fat_g: 20, user: user) }
  let!(:other_meal) { other_plan.meals.create!(position: 1, name: "X", scheduled_time: Time.utc(2000, 1, 1, 7, 0), target_kcal: 500, target_protein_g: 40, target_carbs_g: 40, target_fat_g: 15, user: user) }

  let!(:weight_goal) do
    Goal.find_or_create_by!(metric: :weight_kg, user: user) do |g|
      g.display_name = "Weight"
      g.unit = "kg"
      g.direction = :down
      g.starting_value = 88.0
      g.target_value = 82.0
    end
  end

  let!(:supp_a) { Supplement.create!(name: "A", dose: "1g", user: user) }
  let!(:supp_b) { Supplement.create!(name: "B", dose: "1g", user: user) }

  before do
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
    Habit.delete_all
    travel_to Time.zone.local(2026, 4, 25, 12, 0)
  end

  after { travel_back }

  describe ".rolling_7_days" do
    it "returns an instance covering the last 7 days inclusive" do
      summary = WeeklySummary.rolling_7_days(today: Date.new(2026, 4, 26))
      expect(summary.start_date).to eq(Date.new(2026, 4, 20))
      expect(summary.end_date).to eq(Date.new(2026, 4, 26))
    end

    it "defaults to Current.user when no user is provided" do
      summary = WeeklySummary.rolling_7_days
      expect(summary.user).to eq(user)
    end
  end

  describe "#adherence_pct" do
    it "excludes habits belonging to other users" do
      user_b = create(:user)
      Habit.create!(label: "Other", position: 1, user: user_b)

      Habit.create!(label: "Mine", position: 1, user: user)
      log = DailyLog.create!(date: Date.current, plan: plan)
      log.habit_entries.create!(habit: Habit.where(label: "Mine").first, value: 1)

      summary = WeeklySummary.rolling_7_days(user: user)
      # User A: 1 done, 1 total. 100%.
      # Noise: User B's template should not increase the denominator.
      expect(summary.adherence_pct).to eq(100)
    end

    it "averages each daily log's habit_adherence_pct" do
      Habit.create!(label: "X", position: 1, user: user)
      Habit.create!(label: "Y", position: 2, user: user)

      log1 = DailyLog.create!(date: Date.current - 2, plan: plan)
      log1.habit_entries.create!(habit: Habit.first, value: 1)
      log1.habit_entries.create!(habit: Habit.last, value: 1)

      log2 = DailyLog.create!(date: Date.current - 1, plan: plan)
      log2.habit_entries.create!(habit: Habit.first, value: 1)

      summary = WeeklySummary.rolling_7_days
      expect(summary.adherence_pct).to eq(75)
    end

    it "is nil when no logs exist in the window" do
      DailyLog.destroy_all
      expect(WeeklySummary.rolling_7_days.adherence_pct).to be_nil
    end

    it "averages logs that have zero completions as 0% in the mean" do
      Habit.create!(label: "X", position: 1, user: user)
      Habit.create!(label: "Y", position: 2, user: user)

      log1 = DailyLog.create!(date: Date.current - 1, plan: plan)
      log1.habit_entries.create!(habit: Habit.first, value: 1)
      log1.habit_entries.create!(habit: Habit.last, value: 1)

      DailyLog.create!(date: Date.current, plan: plan) # zero completions

      summary = WeeklySummary.rolling_7_days
      expect(summary.adherence_pct).to eq(50)
    end

    it "excludes logs from the day before the window" do
      Habit.create!(label: "X", position: 1, user: user)
      out_of_window = DailyLog.create!(date: Date.current - 7, plan: plan)
      out_of_window.habit_entries.create!(habit: Habit.first, value: 1)

      expect(WeeklySummary.rolling_7_days.adherence_pct).to be_nil
    end

    it "includes logs from exactly 6 days ago (window boundary)" do
      Habit.create!(label: "X", position: 1, user: user)
      log = DailyLog.create!(date: Date.current - 6, plan: plan)
      log.habit_entries.create!(habit: Habit.first, value: 1)

      expect(WeeklySummary.rolling_7_days.adherence_pct).to eq(100)
    end

    it "ignores rating habits symmetrically — they don't inflate the denominator or numerator" do
      binary = Habit.create!(label: "Binary", position: 1, user: user)
      rating = Habit.create!(label: "Rating", position: 2, user: user, kind: :rating, rating_scale: 5)

      log = DailyLog.create!(date: Date.current, plan: plan)
      log.habit_entries.create!(habit: binary, value: 1)
      HabitEntry.set_value!(daily_log: log, habit: rating, value: 5)

      # 1 of 1 scoreable habit done = 100%. If the rating leaked in as a
      # second denominator slot this would be 50%.
      summary = WeeklySummary.rolling_7_days
      expect(summary.adherence_pct).to eq(100)
    end

    it "caps a day's contribution at 100% when a done habit is archived later the same day" do
      kept = Habit.create!(label: "Kept", position: 1, user: user)
      archived = Habit.create!(label: "Archived", position: 2, user: user)

      log = DailyLog.create!(date: Date.current, plan: plan)
      log.habit_entries.create!(habit: kept, value: 1)
      log.habit_entries.create!(habit: archived, value: 1)
      archived.discard!

      # Denominator for today = 1 (`kept` only — `archived` was discarded
      # earlier today, so kept_on(date) drops it). A numerator that ignores
      # kept_on(date) still counts both done entries: 2/1 = 200%.
      summary = WeeklySummary.rolling_7_days
      expect(summary.adherence_pct).to eq(100)
    end

    it "does not let an archived-and-done habit inflate the numerator above the day's denominator" do
      Habit.create!(label: "Kept", position: 1, user: user) # binary, no entry — not done
      archived = Habit.create!(label: "Archived", position: 2, user: user)

      log = DailyLog.create!(date: Date.current, plan: plan)
      log.habit_entries.create!(habit: archived, value: 1)
      archived.discard!

      # Denominator for today = 1 (`Kept` only, not done). The numerator
      # must apply the same per-day kept_on cutoff, or `archived`'s
      # already-logged entry still counts: 1/1 = 100% despite zero kept
      # habits being done.
      summary = WeeklySummary.rolling_7_days
      expect(summary.adherence_pct).to eq(0)
    end
  end

  describe "#weight_delta_kg" do
    it "excludes weight goals and entries belonging to other users" do
      weight_goal.destroy! # remove user's own goal to ensure any result is a leak

      user_b = create(:user)
      goal_b = Goal.create!(metric: :weight_kg, user: user_b, display_name: "Weight B", unit: "kg", direction: :down, starting_value: 100.0, target_value: 90.0)
      goal_b.biomarker_entries.create!(recorded_on: Date.current - 6, value: 100.0)
      goal_b.biomarker_entries.create!(recorded_on: Date.current,     value: 95.0)

      summary = WeeklySummary.rolling_7_days(user: user)
      # User has no goal, so result must be nil.
      # If unscoped, it would pick up goal_b and return -5.0.
      expect(summary.weight_delta_kg).to be_nil
    end

    it "returns end-weight minus start-weight" do
      weight_goal.biomarker_entries.create!(recorded_on: Date.current - 6, value: 86.0)
      weight_goal.biomarker_entries.create!(recorded_on: Date.current,     value: 85.4)
      expect(WeeklySummary.rolling_7_days.weight_delta_kg).to eq(-0.6)
    end

    it "uses the latest weight on/before each endpoint when none exists inside the window" do
      weight_goal.biomarker_entries.create!(recorded_on: Date.current - 30, value: 90.0)
      weight_goal.biomarker_entries.create!(recorded_on: Date.current - 1,  value: 88.5)
      expect(WeeklySummary.rolling_7_days.weight_delta_kg).to eq(-1.5)
    end

    it "is nil when there is no weight on/before the start" do
      weight_goal.biomarker_entries.create!(recorded_on: Date.current, value: 85.0)
      expect(WeeklySummary.rolling_7_days.weight_delta_kg).to be_nil
    end
  end

  describe "#meal_completion_pct" do
    it "totals meal_completions over the sum of each day's plan.meals.count" do
      log1 = DailyLog.create!(date: Date.current - 1, plan: plan)
      log1.meal_completions.create!(meal: meal_a, completed_at: 1.day.ago)
      log1.meal_completions.create!(meal: meal_b, completed_at: 1.day.ago)

      log2 = DailyLog.create!(date: Date.current, plan: plan)
      log2.meal_completions.create!(meal: meal_a, completed_at: Time.current)

      summary = WeeklySummary.rolling_7_days
      expect(summary.meal_completion_pct).to eq(75)
    end

    it "excludes logs and completions belonging to other users" do
      user_b = create(:user)
      plan_b = Plan.create!(slug: "active", user: user_b, name: "B", target_kcal: 2000, target_protein_g: 180, target_carbs_g: 180, target_fat_g: 70)
      plan_b.meals.create!(position: 1, name: "X", scheduled_time: Time.utc(2000, 1, 1, 7, 0), target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10, user: user_b)
      log_b = DailyLog.create!(date: Date.current, plan: plan_b, user: user_b)
      log_b.meal_completions.create!(meal: plan_b.meals.first, completed_at: Time.current)

      log_a = DailyLog.create!(date: Date.current, plan: plan)
      log_a.meal_completions.create!(meal: meal_a, completed_at: Time.current)

      summary = WeeklySummary.rolling_7_days(user: user)
      # User A: 1 completion / (1 log * 2 meals in plan) = 50%.
      # Noise: User B's log and completion should not be counted.
      expect(summary.meal_completion_pct).to eq(50)
    end

    it "includes logs belonging to the requested user" do
      log = DailyLog.create!(date: Date.current, plan: plan)
      summary = WeeklySummary.rolling_7_days(user: user)
      # Verify the summary is correctly calculating metrics for the user
      expect(summary.meal_completion_pct).not_to be_nil
    end


    it "follows each day's plan when the plan changes mid-week" do
      log1 = DailyLog.create!(date: Date.current - 1, plan: plan)
      log1.meal_completions.create!(meal: meal_a, completed_at: 1.day.ago)

      log2 = DailyLog.create!(date: Date.current, plan: other_plan)
      log2.meal_completions.create!(meal: other_meal, completed_at: Time.current)

      summary = WeeklySummary.rolling_7_days
      expect(summary.meal_completion_pct).to eq(67)
    end

    it "is nil when no logs are present" do
      DailyLog.destroy_all
      expect(WeeklySummary.rolling_7_days.meal_completion_pct).to be_nil
    end
  end

  describe "#supplement_completion_pct" do
    it "excludes supplements and completions belonging to other users" do
      Supplement.delete_all
      user_b = create(:user)
      supp_b = Supplement.create!(name: "Other", dose: "1g", user: user_b)

      # Use a distinct date for user_b to avoid uniqueness collision if user_b is somehow linked to user
      # though they are separate users. Actually, DailyLog uniqueness is scope: :user_id.
      # The failure happened because I didn't provide user_b to DailyLog.create!,
      # and it probably defaulted to Current.user (which is user).
      log_b = DailyLog.create!(date: Date.current, plan: Plan.create!(slug: "active", user: user_b, name: "B", target_kcal: 2000, target_protein_g: 180, target_carbs_g: 180, target_fat_g: 70), user: user_b)
      log_b.supplement_completions.create!(supplement: supp_b, taken_at: Time.current)

      mine = Supplement.create!(name: "Mine", dose: "1g", user: user)
      log_a = DailyLog.create!(date: Date.current, plan: plan, user: user)
      log_a.supplement_completions.create!(supplement: mine, taken_at: Time.current)

      summary = WeeklySummary.rolling_7_days(user: user)
      # 1 completion, 1 expected (mine) * 7 days = 7. 1/7 = 14.28% -> 14%.
      # Noise: User B's supplement and completion should not be counted.
      expect(summary.supplement_completion_pct).to eq(14)
    end

    it "totals supplement_completions over Supplement.count * days_in_window" do
      log1 = DailyLog.create!(date: Date.current - 1, plan: plan)
      log1.supplement_completions.create!(supplement: supp_a, taken_at: 1.day.ago)
      log1.supplement_completions.create!(supplement: supp_b, taken_at: 1.day.ago)

      log2 = DailyLog.create!(date: Date.current, plan: plan)
      log2.supplement_completions.create!(supplement: supp_a, taken_at: Time.current)

      expect(WeeklySummary.rolling_7_days.supplement_completion_pct).to eq(21)
    end

    it "is nil when there are no supplements configured" do
      Supplement.destroy_all
      expect(WeeklySummary.rolling_7_days.supplement_completion_pct).to be_nil
    end
  end
end
