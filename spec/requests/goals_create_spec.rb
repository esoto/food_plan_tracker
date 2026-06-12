require "rails_helper"

RSpec.describe "GoalsController#create (first-run weight goal)", type: :request do
  let!(:user) { create(:user, password: "password12345") }

  before do
    sign_in_as(user)
    create(:plan, slug: "active", user: user)
  end

  it "creates the weight goal, logs the first entry, and syncs today's log" do
    post goals_path, params: { goal: { starting_value: 82.5, target_value: 75 } }

    expect(response).to redirect_to(root_path)
    goal = user.goals.weight_kg.first
    expect(goal).to be_present
    expect(goal.starting_value).to eq(82.5)
    expect(goal.target_value).to eq(75)
    expect(goal.biomarker_entries.count).to eq(1)
    expect(goal.biomarker_entries.first.value).to eq(82.5)
    expect(DailyLog.find_by!(user: user, date: Date.current).weight_kg).to eq(82.5)
  end

  it "is a no-op when a weight goal already exists" do
    create(:goal, :weight, user: user, target_value: 70)

    expect {
      post goals_path, params: { goal: { starting_value: 82.5, target_value: 75 } }
    }.not_to change(Goal, :count)
    expect(response).to redirect_to(root_path)
    expect(user.goals.weight_kg.first.target_value).to eq(70)
  end

  it "rejects invalid values with a friendly redirect" do
    post goals_path, params: { goal: { starting_value: "", target_value: 75 } }

    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to be_present
    expect(Goal.count).to eq(0)
  end

  it "rejects an unauthenticated POST without creating anything" do
    delete session_path

    expect {
      post goals_path, params: { goal: { starting_value: 82.5, target_value: 75 } }
    }.not_to change(Goal, :count)
    expect(response).to redirect_to(new_session_path)
  end

  it "ignores an injected user_id and never creates for another user" do
    other = create(:user)

    post goals_path, params: { goal: { starting_value: 82.5, target_value: 75, user_id: other.id } }

    expect(user.goals.weight_kg.count).to eq(1)
    expect(Goal.where(user: other)).to be_empty
  end
end
