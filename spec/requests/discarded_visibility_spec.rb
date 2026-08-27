require "rails_helper"

# These confirm the existing user-facing pages and tracking endpoints
# transparently filter out anything that's been soft-deleted.
RSpec.describe "Discarded supplement and habit visibility", type: :request do
  let!(:user) { create(:user) }

  before do
    create(:plan, slug: "exercise", name: "Exercise day", user: user)
    sign_in_as(user)
  end

  describe "GET /supplements" do
    it "does not render schedules whose supplement is discarded" do
      kept = create(:supplement, name: "Magnesium", user: user)
      discarded = create(:supplement, name: "OldStack", discarded_at: 1.day.ago, user: user)
      kept.supplement_schedules.create!(time_slot: "morning", position: 0)
      discarded.supplement_schedules.create!(time_slot: "morning", position: 1)

      get supplements_path

      expect(response.body).to include("Magnesium")
      expect(response.body).not_to include("OldStack")
    end
  end

  describe "POST /supplement_completions" do
    it "404s for a discarded supplement" do
      sup = create(:supplement, discarded_at: 1.day.ago, user: user)

      post supplement_completions_path, params: { supplement_id: sup.id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /habits" do
    it "does not list discarded habits" do
      Habit.delete_all
      create(:habit, label: "Drink water", position: 0, user: user)
      create(:habit, label: "OldHabit", position: 1, discarded_at: 1.day.ago, user: user)

      get habits_path

      expect(response.body).to include("Drink water")
      expect(response.body).not_to include("OldHabit")
    end
  end

  describe "PATCH /habit_entries/:id" do
    it "404s when the underlying habit is discarded" do
      habit = create(:habit, position: 0, discarded_at: 1.day.ago, user: user)
      plan = create(:plan, user: user)
      log = create(:daily_log, plan: plan, user: user)

      patch habit_entry_path(habit), params: { daily_log_id: log.id, checked: "1" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
