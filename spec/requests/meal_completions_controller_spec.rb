require "rails_helper"

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

    expect(flash[:notice]).to match(/Copied 0 meals/)
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
