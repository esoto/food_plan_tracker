require "rails_helper"

RSpec.describe HabitEntriesController, type: :request do
  let(:user) { create(:user) }
  let(:plan) { create(:plan, user: user) }
  let(:habit) { create(:habit, user: user, label: "Walk", position: 0) }
  let(:daily_log) { create(:daily_log, user: user, plan: plan, date: Date.current) }

  before { sign_in_as(user) }

  describe "PATCH /habit_entries/:id" do
    it "checks the user's own habit for the requested day" do
      patch habit_entry_path(habit),
            params: { daily_log_id: daily_log.id, checked: "1" }

      entry = daily_log.habit_entries.find_by(habit: habit)
      expect(entry.checked).to be true
      expect(response).to have_http_status(:redirect)
    end

    it "unchecks the habit when checked: 0 is passed" do
      create(:habit_entry, daily_log: daily_log, habit: habit, checked: true)

      patch habit_entry_path(habit),
            params: { daily_log_id: daily_log.id, checked: "0" }

      expect(daily_log.habit_entries.find_by(habit: habit).checked).to be false
    end

    it "POSITIVE CONTROL: PATCH on the user's own past-day log still works" do
      past_plan = create(:plan, slug: "active-past", user: user, name: "Past plan")
      past_log  = create(:daily_log, user: user, plan: past_plan, date: 2.days.ago.to_date)
      create(:habit_entry, daily_log: past_log, habit: habit, checked: false)

      patch habit_entry_path(habit),
            params: { daily_log_id: past_log.id, checked: "1" }

      expect(past_log.habit_entries.find_by(habit: habit).checked).to be true
    end

    it "returns 404 and preserves untouched state when habit_id belongs to another user" do
      user_b = create(:user)
      _b_habit = create(:habit, user: user_b, label: "Other's Walk", position: 0)

      patch habit_entry_path(_b_habit),
            params: { daily_log_id: daily_log.id, checked: "1" }

      expect(response).to have_http_status(:not_found)
      # The user's own habit should NOT have been toggled.
      expect(daily_log.habit_entries.find_by(habit: habit)).to be_nil
    end

    it "returns 404 when daily_log_id belongs to another user" do
      user_b = create(:user)
      plan_b = create(:plan, user: user_b)
      _log_b = create(:daily_log, user: user_b, plan: plan_b, date: Date.current)

      patch habit_entry_path(habit),
            params: { daily_log_id: _log_b.id, checked: "1" }

      expect(response).to have_http_status(:not_found)
      # No entry should be written to either log.
      expect(_log_b.habit_entries.count).to eq(0)
      expect(daily_log.habit_entries.count).to eq(0)
    end
  end
end
