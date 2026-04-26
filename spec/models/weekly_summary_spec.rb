require "rails_helper"

RSpec.describe WeeklySummary, type: :model do
  let!(:plan) do
    Plan.find_or_create_by!(slug: "active") do |p|
      p.name = "Active day"
      p.target_kcal = 2000
      p.target_protein_g = 180
      p.target_carbs_g = 180
      p.target_fat_g = 70
    end
  end
  let!(:other_plan) do
    Plan.find_or_create_by!(slug: "exercise") do |p|
      p.name = "Exercise day"
      p.target_kcal = 2200
      p.target_protein_g = 180
      p.target_carbs_g = 180
      p.target_fat_g = 70
    end
  end
  let!(:meal_a) { plan.meals.create!(position: 1, name: "A", scheduled_time: Time.utc(2000, 1, 1, 7, 0), target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10) }
  let!(:meal_b) { plan.meals.create!(position: 2, name: "B", scheduled_time: Time.utc(2000, 1, 1, 12, 0), target_kcal: 600, target_protein_g: 45, target_carbs_g: 60, target_fat_g: 20) }
  let!(:other_meal) { other_plan.meals.create!(position: 1, name: "X", scheduled_time: Time.utc(2000, 1, 1, 7, 0), target_kcal: 500, target_protein_g: 40, target_carbs_g: 40, target_fat_g: 15) }

  let!(:weight_goal) do
    Goal.find_or_create_by!(metric: :weight_kg) do |g|
      g.display_name = "Weight"
      g.unit = "kg"
      g.direction = :down
      g.starting_value = 88.0
      g.target_value = 82.0
    end
  end

  let!(:supp_a) { Supplement.create!(name: "A", dose: "1g") }
  let!(:supp_b) { Supplement.create!(name: "B", dose: "1g") }

  before { ChecklistTemplate.delete_all }

  describe ".rolling_7_days" do
    it "returns an instance covering the last 7 days inclusive" do
      summary = WeeklySummary.rolling_7_days(today: Date.new(2026, 4, 26))
      expect(summary.start_date).to eq(Date.new(2026, 4, 20))
      expect(summary.end_date).to eq(Date.new(2026, 4, 26))
    end
  end

  describe "#adherence_pct" do
    it "averages each daily log's checklist_adherence_pct" do
      ChecklistTemplate.create!(label: "X", position: 1)
      ChecklistTemplate.create!(label: "Y", position: 2)

      log1 = DailyLog.create!(date: Date.current - 2, plan: plan)
      log1.checklist_completions.create!(checklist_template: ChecklistTemplate.first, checked: true)
      log1.checklist_completions.create!(checklist_template: ChecklistTemplate.last, checked: true)

      log2 = DailyLog.create!(date: Date.current - 1, plan: plan)
      log2.checklist_completions.create!(checklist_template: ChecklistTemplate.first, checked: true)

      summary = WeeklySummary.rolling_7_days
      expect(summary.adherence_pct).to eq(75)
    end

    it "is nil when no logs exist in the window" do
      DailyLog.destroy_all
      expect(WeeklySummary.rolling_7_days.adherence_pct).to be_nil
    end
  end

  describe "#weight_delta_kg" do
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
