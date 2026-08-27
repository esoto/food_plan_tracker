require "rails_helper"

RSpec.describe SupplementCompletionsController, type: :request do
  let(:user) { create(:user) }
  let(:plan) { create(:plan, user: user) }
  let(:supplement) { create(:supplement, user: user, name: "Magnesium") }
  let(:daily_log) { create(:daily_log, user: user, plan: plan, date: Date.current) }

  before { sign_in_as(user) }

  describe "POST /supplement_completions" do
    it "creates a completion for the user's own supplement" do
      expect {
        post supplement_completions_path, params: { supplement_id: supplement.id, daily_log_id: daily_log.id }
      }.to change { daily_log.supplement_completions.count }.from(0).to(1)

      expect(response).to have_http_status(:redirect)
    end

    it "returns 404 when supplement_id belongs to another user" do
      user_b = create(:user)
      supplement_b = create(:supplement, user: user_b, name: "Other's Magnesium")

      expect {
        post supplement_completions_path, params: { supplement_id: supplement_b.id, daily_log_id: daily_log.id }
      }.not_to change(SupplementCompletion, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when daily_log_id belongs to another user" do
      user_b = create(:user)
      plan_b = create(:plan, user: user_b)
      _log_b = create(:daily_log, user: user_b, plan: plan_b, date: Date.current)

      expect {
        post supplement_completions_path, params: { supplement_id: supplement.id, daily_log_id: _log_b.id }
      }.not_to change(SupplementCompletion, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "synchronizes the 'Took Fibrotina with dinner' habit on create" do
      fib_habit = create(:habit, user: user,
                                  label: "Took Fibrotina with dinner",
                                  position: 0)
      fib_supplement = create(:supplement, user: user, name: "Fibrotina 145mg")

      expect {
        post supplement_completions_path, params: { supplement_id: fib_supplement.id, daily_log_id: daily_log.id }
      }.to change {
        daily_log.habit_entries.find_by(habit: fib_habit)&.checked
      }.from(nil).to(true)
    end

    it "does not pick up another user's Fibrotina habit (cross-tenant habit sync)" do
      user_b = create(:user)
      _b_habit = create(:habit, user: user_b,
                                 label: "Took Fibrotina with dinner",
                                 position: 0)
      own_habit = create(:habit, user: user,
                                  label: "Drink water",
                                  position: 0)
      fib_supplement = create(:supplement, user: user, name: "Fibrotina 145mg")

      post supplement_completions_path, params: { supplement_id: fib_supplement.id, daily_log_id: daily_log.id }

      # No habit_entry should reference the other user's habit, and
      # our own non-Fibrotina habit stays untouched (no entry row created
      # because the controller scopes habit lookup to Current.user).
      expect(daily_log.habit_entries.where(habit: _b_habit)).to be_empty
      expect(daily_log.habit_entries.where(habit: own_habit)).to be_empty
    end
  end

  describe "DELETE /supplement_completions/:id" do
    it "deletes the user's own completion" do
      completion = create(:supplement_completion, daily_log: daily_log, supplement: supplement)

      expect {
        delete supplement_completion_path(completion)
      }.to change { daily_log.supplement_completions.count }.from(1).to(0)

      expect(response).to have_http_status(:redirect)
    end

    it "POSITIVE CONTROL: destroy on a past-day completion still works" do
      past_plan = create(:plan, slug: "active-past", user: user, name: "Past plan")
      past_log  = create(:daily_log, user: user, plan: past_plan, date: 3.days.ago.to_date)
      past_supp = create(:supplement, user: user, name: "Past Magnesium")
      completion = create(:supplement_completion, daily_log: past_log, supplement: past_supp)

      expect {
        delete supplement_completion_path(completion)
      }.to change { past_log.supplement_completions.count }.from(1).to(0)

      expect(response).to have_http_status(:redirect)
    end

    it "returns 404 and preserves another user's completion" do
      user_b = create(:user)
      plan_b = create(:plan, user: user_b)
      log_b  = create(:daily_log, user: user_b, plan: plan_b, date: 1.day.ago.to_date)
      supp_b = create(:supplement, user: user_b, name: "Other's Magnesium")
      completion = create(:supplement_completion, daily_log: log_b, supplement: supp_b)

      expect {
        delete supplement_completion_path(completion)
      }.not_to change(SupplementCompletion, :count)

      expect(response).to have_http_status(:not_found)
      expect(completion.reload).to be_persisted
    end
  end
end
