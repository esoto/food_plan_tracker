require "rails_helper"

RSpec.describe MealCompletionsController, type: :request do
  describe "POST /meal_completions" do
    let(:plan) { create(:plan, user: Current.user) }
    let(:meal) do
      plan.meals.create!(position: 1, name: "Breakfast", user: Current.user,
                         scheduled_time: Time.utc(2000, 1, 1, 7, 0),
                         target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10)
    end
    let(:daily_log) { create(:daily_log, user: Current.user, plan: plan, date: Date.current) }

    before { sign_in_as }

    it "creates a completion for the user's own meal" do
      expect {
        post meal_completions_path, params: { meal_id: meal.id, daily_log_id: daily_log.id }
      }.to change { daily_log.meal_completions.count }.from(0).to(1)

      expect(response).to have_http_status(:ok)
    end

    it "returns 404 when meal_id belongs to another user" do
      user_b = create(:user)
      plan_b = create(:plan, user: user_b)
      meal_b = create(:meal, user: user_b, plan: plan_b)

      expect {
        post meal_completions_path, params: { meal_id: meal_b.id, daily_log_id: daily_log.id }
      }.not_to change(MealCompletion, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when daily_log_id belongs to another user" do
      user_b = create(:user)
      plan_b = create(:plan, user: user_b)
      _log_b = create(:daily_log, user: user_b, plan: plan_b, date: Date.current)

      expect {
        post meal_completions_path, params: { meal_id: meal.id, daily_log_id: _log_b.id }
      }.not_to change(MealCompletion, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /meal_completions/:id" do
    let(:plan) { create(:plan, user: Current.user) }
    let(:meal) do
      plan.meals.create!(position: 1, name: "Breakfast", user: Current.user,
                         scheduled_time: Time.utc(2000, 1, 1, 7, 0),
                         target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10)
    end
    let(:daily_log) { create(:daily_log, user: Current.user, plan: plan, date: Date.current) }

    before { sign_in_as }

    it "deletes the user's own completion and renders the meal card partial" do
      completion = create(:meal_completion, daily_log: daily_log, meal: meal)

      expect {
        delete meal_completion_path(completion)
      }.to change { daily_log.meal_completions.count }.from(1).to(0)

      expect(response).to have_http_status(:ok)
    end

    it "POSITIVE CONTROL: destroy on a past-day completion still works" do
      past_plan = create(:plan, slug: "active-past", user: Current.user, name: "Past plan")
      past_log = create(:daily_log, user: Current.user, plan: past_plan, date: 3.days.ago.to_date)
      past_meal = create(:meal, user: Current.user, plan: past_plan)
      completion = create(:meal_completion, daily_log: past_log, meal: past_meal)

      expect {
        delete meal_completion_path(completion)
      }.to change { past_log.meal_completions.count }.from(1).to(0)

      expect(response).to have_http_status(:ok)
    end

    it "returns 404 and preserves another user's completion" do
      user_b = create(:user)
      plan_b = create(:plan, user: user_b)
      log_b = create(:daily_log, user: user_b, plan: plan_b, date: 1.day.ago.to_date)
      meal_b = create(:meal, user: user_b, plan: plan_b)
      completion = create(:meal_completion, daily_log: log_b, meal: meal_b)

      expect {
        delete meal_completion_path(completion)
      }.not_to change { MealCompletion.count }

      expect(response).to have_http_status(:not_found)
      expect(completion.reload).to be_persisted
    end
  end
end

RSpec.describe "MealCompletionsController#copy_yesterday", type: :request do
  let(:plan) { seed_plan(slug: "active") }
  let(:other_plan) { seed_plan(slug: "exercise", target_kcal: 2200) }
  let(:breakfast) do
    plan.meals.create!(position: 1, name: "Breakfast",
                       scheduled_time: Time.utc(2000, 1, 1, 7, 0),
                       target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10)
  end
  let(:lunch) do
    plan.meals.create!(position: 2, name: "Lunch",
                       scheduled_time: Time.utc(2000, 1, 1, 12, 30),
                       target_kcal: 600, target_protein_g: 45, target_carbs_g: 60, target_fat_g: 20)
  end

  before { sign_in_as }

  it "copies yesterday's completions when both days share a plan" do
    yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
    yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)
    yesterday.meal_completions.create!(meal: lunch, completed_at: 1.day.ago)

    today = DailyLog.today
    expect {
      post copy_yesterday_meal_completions_path
    }.to change { today.meal_completions.count }.from(0).to(2)

    expect(response).to redirect_to(menu_path)
    expect(flash[:notice]).to match(/Copied 2 meals/)
  end

  it "stamps copied completions with today's time, not yesterday's" do
    yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
    yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)

    post copy_yesterday_meal_completions_path

    copied = DailyLog.today.meal_completions.find_by!(meal: breakfast)
    expect(copied.completed_at).to be_within(5.seconds).of(Time.current)
  end

  it "preserves today's pre-existing completion timestamps when filling in missing meals" do
    yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
    yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)
    yesterday.meal_completions.create!(meal: lunch, completed_at: 1.day.ago)

    today = DailyLog.today
    pre_existing_time = 2.hours.ago.change(usec: 0)
    today.meal_completions.create!(meal: breakfast, completed_at: pre_existing_time)

    expect {
      post copy_yesterday_meal_completions_path
    }.to change { today.meal_completions.count }.from(1).to(2)

    expect(today.meal_completions.find_by!(meal: breakfast).completed_at).to eq(pre_existing_time)
    expect(flash[:notice]).to match(/Copied 1 meal/)
  end

  it "is idempotent — already-completed meals don't duplicate" do
    yesterday = DailyLog.create!(date: Date.current - 1, plan: plan)
    yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)
    DailyLog.today.meal_completions.create!(meal: breakfast, completed_at: Time.current)

    expect {
      post copy_yesterday_meal_completions_path
    }.not_to change { DailyLog.today.meal_completions.count }

    expect(flash[:notice]).to match(/Already up to date/)
  end

  it "redirects with alert when plans differ" do
    other_plan
    yesterday = DailyLog.create!(date: Date.current - 1, plan: other_plan)
    yesterday.meal_completions.create!(meal: breakfast, completed_at: 1.day.ago)
    DailyLog.today # ensure today is on the active plan

    expect {
      post copy_yesterday_meal_completions_path
    }.not_to change(MealCompletion, :count)

    expect(flash[:alert]).to match(/doesn't match/)
  end

  it "redirects with alert and writes nothing when there is no yesterday log" do
    plan
    DailyLog.where(date: Date.current - 1).destroy_all

    expect {
      post copy_yesterday_meal_completions_path
    }.not_to change(MealCompletion, :count)

    expect(flash[:alert]).to match(/No log from yesterday/)
  end
end
