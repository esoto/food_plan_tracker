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

    it "sets the value directly when the `value` param is given" do
      quantity_habit = create(:habit, :quantity, user: user, label: "Water", position: 1)

      patch habit_entry_path(quantity_habit),
            params: { daily_log_id: daily_log.id, value: "3" }

      entry = daily_log.habit_entries.find_by(habit: quantity_habit)
      expect(entry.value).to eq(3.0)
      expect(response).to have_http_status(:redirect)
    end

    it "increments the value via the `delta` param, summing across two PATCHes" do
      quantity_habit = create(:habit, :quantity, user: user, label: "Water", position: 1)

      patch habit_entry_path(quantity_habit),
            params: { daily_log_id: daily_log.id, delta: "3" }
      patch habit_entry_path(quantity_habit),
            params: { daily_log_id: daily_log.id, delta: "2" }

      entry = daily_log.habit_entries.find_by(habit: quantity_habit)
      expect(entry.value).to eq(5.0)
    end

    it "maps the legacy `checked` param to value 1.0 / 0.0" do
      patch habit_entry_path(habit),
            params: { daily_log_id: daily_log.id, checked: "1" }

      entry = daily_log.habit_entries.find_by(habit: habit)
      expect(entry.value).to eq(1.0)

      patch habit_entry_path(habit),
            params: { daily_log_id: daily_log.id, checked: "0" }

      expect(entry.reload.value).to eq(0.0)
    end

    it "rejects an out-of-range rating value, writes nothing, and redirects with an alert" do
      rating_habit = create(:habit, :rating, user: user, label: "Mood", position: 1, rating_scale: 5)

      patch habit_entry_path(rating_habit),
            params: { daily_log_id: daily_log.id, value: "6" }

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
      expect(daily_log.habit_entries.find_by(habit: rating_habit)).to be_nil
    end

    it "rejects a delta param on a rating habit, writes nothing, and redirects with an alert" do
      rating_habit = create(:habit, :rating, user: user, label: "Mood", position: 1, rating_scale: 5)

      patch habit_entry_path(rating_habit),
            params: { daily_log_id: daily_log.id, delta: "99" }

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
      expect(daily_log.habit_entries.find_by(habit: rating_habit)).to be_nil
    end
  end
end
