require "rails_helper"

RSpec.describe Settings::HabitsController, type: :request do
  before { sign_in_as }

  describe "GET /settings/habits" do
    it "lists kept habits and excludes discarded" do
      Habit.delete_all
      create(:habit, label: "Drink water", position: 0, user: Current.user)
      create(:habit, label: "Old habit", position: 1, discarded_at: 1.day.ago, user: Current.user)

      get settings_habits_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Drink water")
      expect(response.body).not_to include("Old habit")
    end
  end

  describe "GET /settings/habits/archived" do
    it "lists only discarded habits" do
      Habit.delete_all
      create(:habit, label: "Drink water", position: 0, user: Current.user)
      create(:habit, label: "Old habit", position: 1, discarded_at: 1.day.ago, user: Current.user)

      get archived_settings_habits_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Old habit")
      expect(response.body).not_to include("Drink water")
    end
  end

  describe "POST /settings/habits" do
    it "creates a habit with auto-incremented position" do
      Habit.delete_all
      create(:habit, label: "First", position: 0, user: Current.user)

      expect {
        post settings_habits_path, params: { habit: { label: "Second" } }
      }.to change(Habit.kept, :count).by(1)

      expect(Habit.kept.find_by(label: "Second").position).to eq(1)
    end

    it "renders new on validation failure" do
      post settings_habits_path, params: { habit: { label: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /settings/habits/:id" do
    it "updates label, description, icon" do
      habit = create(:habit, label: "Old", position: 0, user: Current.user)
      patch settings_habit_path(habit), params: {
        habit: { label: "New", description: "x", icon: "💧" }
      }

      habit.reload
      expect(habit.label).to eq("New")
      expect(habit.description).to eq("x")
      expect(habit.icon).to eq("💧")
    end
  end

  describe "DELETE /settings/habits/:id" do
    it "soft-deletes and preserves completion records" do
      habit = create(:habit, position: 0, user: Current.user)
      plan = create(:plan, user: habit.user)
      log = create(:daily_log, plan: plan, user: habit.user)
      completion = create(:habit_entry, habit: habit, daily_log: log)

      expect {
        delete settings_habit_path(habit)
      }.not_to change(HabitEntry, :count)

      expect(habit.reload.discarded_at).to be_present
      expect(completion.reload).to be_persisted
    end
  end

  describe "PATCH /settings/habits/:id/restore" do
    it "restores a discarded habit at the end of the position list" do
      Habit.delete_all
      create(:habit, label: "A", position: 0, user: Current.user)
      create(:habit, label: "B", position: 1, user: Current.user)
      restored = create(:habit, label: "Old", position: 2, discarded_at: 1.day.ago, user: Current.user)

      patch restore_settings_habit_path(restored)

      expect(restored.reload.discarded_at).to be_nil
      expect(restored.position).to eq(2)
    end
  end

  describe "PATCH /settings/habits/:id/move_up and move_down" do
    let!(:habits) do
      Habit.delete_all
      [
        create(:habit, label: "A", position: 0, user: Current.user),
        create(:habit, label: "B", position: 1, user: Current.user),
        create(:habit, label: "C", position: 2, user: Current.user)
      ]
    end

    it "swaps position with the previous habit (move_up)" do
      patch move_up_settings_habit_path(habits[1])
      expect(habits.map { |t| t.reload.position }).to eq([ 1, 0, 2 ])
    end

    it "swaps position with the next habit (move_down)" do
      patch move_down_settings_habit_path(habits[1])
      expect(habits.map { |t| t.reload.position }).to eq([ 0, 2, 1 ])
    end

    it "no-ops at the top edge" do
      patch move_up_settings_habit_path(habits[0])
      expect(habits.map { |t| t.reload.position }).to eq([ 0, 1, 2 ])
    end

    it "no-ops at the bottom edge" do
      patch move_down_settings_habit_path(habits[2])
      expect(habits.map { |t| t.reload.position }).to eq([ 0, 1, 2 ])
    end
  end

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }

    it "index does not list another user's habits" do
      Habit.delete_all
      create(:habit, label: "Mine", position: 0, user: Current.user)
      create(:habit, label: "Theirs", position: 1, user: user_b)

      get settings_habits_path

      expect(response.body).to include("Mine")
      expect(response.body).not_to include("Theirs")
    end

    it "archived does not list another user's habits" do
      Habit.delete_all
      create(:habit, label: "MineArchived", position: 0, discarded_at: 1.day.ago, user: Current.user)
      create(:habit, label: "TheirsArchived", position: 1, discarded_at: 1.day.ago, user: user_b)

      get archived_settings_habits_path

      expect(response.body).to include("MineArchived")
      expect(response.body).not_to include("TheirsArchived")
    end

    it "next_position does not leak — new habit gets position 0, not the other user's count" do
      Habit.delete_all
      # user_b has 3 habits (positions 0,1,2)
      3.times { |i| create(:habit, label: "B#{i}", position: i, user: user_b) }
      # Current.user has 0

      post settings_habits_path, params: { habit: { label: "First" } }

      mine = Habit.find_by(label: "First", user: Current.user)
      expect(mine).to be_present
      expect(mine.position).to eq(0) # not 3
    end

    it "PATCH another user's habit returns 404 and does not mutate it" do
      b = create(:habit, label: "Theirs", position: 0, user: user_b)
      patch settings_habit_path(b), params: { habit: { label: "Hacked" } }

      expect(response).to have_http_status(:not_found)
      expect(b.reload.label).to eq("Theirs")
    end

    it "DELETE another user's habit returns 404 and does not discard it" do
      b = create(:habit, label: "Theirs", position: 0, user: user_b)
      delete settings_habit_path(b)

      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).to be_nil
    end

    it "restore on another user's habit returns 404 and does not restore it" do
      b = create(:habit, label: "Theirs", position: 0,
                 discarded_at: 1.day.ago, user: user_b)
      patch restore_settings_habit_path(b)

      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).not_to be_nil
    end

    it "move_up on another user's habit returns 404 and does not change positions" do
      Habit.delete_all
      a1 = create(:habit, label: "A1", position: 0, user: user_b)
      a2 = create(:habit, label: "A2", position: 1, user: user_b)
      b1 = create(:habit, label: "B1", position: 0, user: Current.user)

      patch move_up_settings_habit_path(a2)

      expect(response).to have_http_status(:not_found)
      # The other user's siblings must be UNCHANGED — the leak would otherwise
      # let user A swap positions on user B's habits via move_up.
      expect(a1.reload.position).to eq(0)
      expect(a2.reload.position).to eq(1)
      # Sanity: user A's own habit is also untouched.
      expect(b1.reload.position).to eq(0)
    end

    it "move_down on another user's habit returns 404 and does not change positions" do
      Habit.delete_all
      c1 = create(:habit, label: "C1", position: 0, user: user_b)
      c2 = create(:habit, label: "C2", position: 1, user: user_b)
      d1 = create(:habit, label: "D1", position: 0, user: Current.user)

      patch move_down_settings_habit_path(c1)

      expect(response).to have_http_status(:not_found)
      # The other user's siblings must be UNCHANGED — the leak would otherwise
      # let user A swap positions on user B's habits via move_down.
      expect(c1.reload.position).to eq(0)
      expect(c2.reload.position).to eq(1)
      # Sanity: user A's own habit is also untouched.
      expect(d1.reload.position).to eq(0)
    end
  end
end
