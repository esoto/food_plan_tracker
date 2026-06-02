require "rails_helper"

RSpec.describe "ProgressController#show", type: :request do
  let(:user) { create(:user, password: "password") }
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

  describe "cross-tenant isolation" do
    it "computes weight goal and goals list from Current.user only" do
      user_a = create(:user, password: "password")
      sign_in_as(user_a)
      create(:plan, slug: "active", user: user_a)

      other  = create(:user)
      goal_b = create(:goal, display_name: "OTHER GOAL", user: other)
      goal_b.biomarker_entries.create!(recorded_on: Date.current - 6, value: 90.0, user: other)
      goal_b.biomarker_entries.create!(recorded_on: Date.current,     value: 88.0, user: other)

      get progress_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("OTHER GOAL")
    end
  end

end
