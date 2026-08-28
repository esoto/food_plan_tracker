require "rails_helper"

RSpec.describe "ProgressController#show", type: :request do
  let(:user) { create(:user, password: "password12345") }
  let!(:plan) { seed_plan(slug: "active") }
  let!(:meal_a) { plan.meals.create!(position: 1, name: "A", scheduled_time: Time.utc(2000, 1, 1, 7, 0), target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10, user: user) }
  let!(:meal_b) { plan.meals.create!(position: 2, name: "B", scheduled_time: Time.utc(2000, 1, 1, 12, 0), target_kcal: 600, target_protein_g: 45, target_carbs_g: 60, target_fat_g: 20, user: user) }
  let!(:weight_goal) do
    Goal.find_or_create_by!(metric: :weight_kg, user: user) do |g|
      g.display_name = "Weight"
      g.unit = "kg"
      g.direction = :down
      g.starting_value = 88.0
      g.target_value = 82.0
    end
  end

  before do
    sign_in_as(user)
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
  end

  it "renders the Last 7 days summary card with all four metric labels" do
    get progress_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Last 7 days")
    expect(response.body).to include("Habits")
    expect(response.body).to include("Weight Δ")
    expect(response.body).to include("Meals")
    expect(response.body).to include("Supplements")
  end

  it "renders em-dashes when the window has no data" do
    DailyLog.destroy_all
    Supplement.destroy_all

    get progress_path

    expect(response.body.scan(/—\s*<\/p>/).size).to eq(4)
  end

  it "renders computed weight delta with a downward arrow when weight is dropping" do
    weight_goal.biomarker_entries.create!(recorded_on: Date.current - 6, value: 86.0)
    weight_goal.biomarker_entries.create!(recorded_on: Date.current,     value: 85.4)

    get progress_path

    expect(response.body).to include("↓ 0.6 kg")
    expect(response.body).to include("text-emerald-600")
  end

  it "renders an upward arrow with rose color when weight is increasing" do
    weight_goal.biomarker_entries.create!(recorded_on: Date.current - 6, value: 85.0)
    weight_goal.biomarker_entries.create!(recorded_on: Date.current,     value: 85.8)

    get progress_path

    expect(response.body).to include("↑ 0.8 kg")
    expect(response.body).to include("text-rose-600")
  end

  it "renders 0 kg with neutral color when weight is unchanged" do
    weight_goal.biomarker_entries.create!(recorded_on: Date.current - 6, value: 85.0)
    weight_goal.biomarker_entries.create!(recorded_on: Date.current,     value: 85.0)

    get progress_path

    expect(response.body).to include("0 kg")
  end

  it "renders meal-completion percent over the last 7 days" do
    log1 = DailyLog.create!(date: Date.current - 1, plan: plan)
    log1.meal_completions.create!(meal: meal_a, completed_at: 1.day.ago)
    log1.meal_completions.create!(meal: meal_b, completed_at: 1.day.ago)
    log2 = DailyLog.create!(date: Date.current, plan: plan)
    log2.meal_completions.create!(meal: meal_a, completed_at: Time.current)

    get progress_path

    expect(response.body).to include("75%")
  end

  describe "rating trends" do
    it "renders the habit label, 7-day average, and delta arrow when the user has kept rating habits" do
      habit = create(:habit, :rating, user: user, label: "Mood", position: 0)

      # Previous 7-day window (13..7 days ago): avg 2.0
      13.downto(7).each do |days_ago|
        log = DailyLog.create!(date: Date.current - days_ago, plan: plan)
        create(:habit_entry, daily_log: log, habit: habit, value: 2)
      end

      # Last 7-day window (6..1 days ago logged, today left unlogged): avg 4.0
      6.downto(1).each do |days_ago|
        log = DailyLog.create!(date: Date.current - days_ago, plan: plan)
        create(:habit_entry, daily_log: log, habit: habit, value: 4)
      end

      get progress_path

      expect(response.body).to include("Ratings")
      expect(response.body).to include("Mood")
      expect(response.body).to include("4.0")
      expect(response.body).to include("↑")
    end

    it "omits the rating trends section when the user has no rating habits" do
      create(:habit, :quantity, user: user, label: "Water", position: 0)

      get progress_path

      expect(response.body).not_to include("Ratings")
    end

    it "excludes discarded rating habits from the section" do
      habit = create(:habit, :rating, user: user, label: "Journaling", position: 0)
      habit.discard!

      get progress_path

      expect(response.body).not_to include("Ratings")
      expect(response.body).not_to include("Journaling")
    end
  end

  describe "cross-tenant isolation" do
    it "computes weight goal and goals list from Current.user only" do
      user_a = create(:user, password: "password12345")
      sign_in_as(user_a)
      create(:plan, slug: "active", user: user_a)

      other  = create(:user)
      # This is the "leak" target: a weight goal for another user
      goal_b = create(:goal,
                     metric: :weight_kg,
                     display_name: "LEAKY WEIGHT",
                     user: other)
      goal_b.biomarker_entries.create!(recorded_on: Date.current - 6, value: 90.0, user: other)
      goal_b.biomarker_entries.create!(recorded_on: Date.current,     value: 88.0, user: other)

      get progress_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("LEAKY WEIGHT")
      expect(response.body).not_to include("↓ 2.0 kg") # Value from goal_b
    end
  end
end
