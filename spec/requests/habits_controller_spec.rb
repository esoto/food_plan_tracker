require "rails_helper"

RSpec.describe "GET /checklist", type: :request do
  before do
    sign_in_as
    create(:plan, slug: "exercise", name: "Exercise day", user: Current.user)
  end

  describe "happy path" do
    it "renders the checklist page" do
      get habits_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Daily habits")
    end

    it "lists the signed-in user's kept templates in display order" do
      create(:habit, label: "B", position: 1, user: Current.user)
      create(:habit, label: "A", position: 0, user: Current.user)

      get habits_path

      expect(response.body).to include("A")
      expect(response.body).to include("B")
      # A should come before B in the rendered HTML
      expect(response.body.index("A")).to be < response.body.index("B")
    end

    it "omits discarded templates" do
      create(:habit, label: "Drink water", position: 0, user: Current.user)
      create(:habit, label: "OldHabit", position: 1,
                                  discarded_at: 1.day.ago, user: Current.user)

      get habits_path

      expect(response.body).to include("Drink water")
      expect(response.body).not_to include("OldHabit")
    end

    it "shows the streak of consecutive days at >=80% adherence" do
      habit = create(:habit, label: "Walk", position: 0, user: Current.user)
      # 3 days in a row, 100% complete.
      3.times do |i|
        date = i.days.ago.to_date
        plan = create(:plan, slug: "active-#{i}", name: "Active #{i}", user: Current.user)
        log = create(:daily_log, user: Current.user, plan: plan, date: date)
        create(:habit_entry, daily_log: log, habit: habit, value: 1)
      end

      get habits_path

      # Streak counter shows the number on the page.
      expect(response.body).to match(/<p class="text-xl font-bold leading-none mt-0\.5">3<\/p>/)
    end

    it "still counts a 100%-binary day toward the streak when a rating habit is also logged low (ratings excluded from adherence)" do
      habit = create(:habit, label: "Walk", position: 0, user: Current.user)
      rating = create(:habit, :rating, label: "Mood", position: 1, user: Current.user, rating_scale: 5)
      plan = create(:plan, slug: "active-rating", name: "Active rating", user: Current.user)
      log = create(:daily_log, user: Current.user, plan: plan, date: Date.current)
      create(:habit_entry, daily_log: log, habit: habit, value: 1)
      HabitEntry.set_value!(daily_log: log, habit: rating, value: 1) # low rating; must not drag adherence down

      get habits_path

      expect(response.body).to match(/<p class="text-xl font-bold leading-none mt-0\.5">1<\/p>/)
    end
  end

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }

    it "does not render another user's templates" do
      create(:habit, label: "Mine", position: 0, user: Current.user)
      create(:habit, label: "Theirs", position: 1, user: user_b)

      get habits_path

      expect(response.body).to include("Mine")
      expect(response.body).not_to include("Theirs")
    end

    it "does not include another user's daily logs in the heatmap/last-30-days" do
      # Set up: signed-in user has 0 daily_logs; user_b has 1 daily_log today
      # with a habit_entry on a uniquely-labeled habit. The
      # template's label would render in the heatmap if user_b's log leaked.
      user_b_plan = create(:plan, slug: "exercise-b", name: "B exercise", user: user_b)
      b_habit = create(:habit, label: "FOREIGN_HEATMAP_MARKER",
                                              position: 0, user: user_b)
      b_log = create(:daily_log, user: user_b, plan: user_b_plan, date: Date.current)
      create(:habit_entry, daily_log: b_log, habit: b_habit, value: 1)

      get habits_path

      expect(response).to have_http_status(:ok)
      # The heatmap renders tooltip/title per day; the foreign completion's
      # template label would surface if user_b's daily_log leaked into
      # @last_30_logs. A regression to `DailyLog.where(date: ...)` (unscoped)
      # would include it.
      expect(response.body).not_to include("FOREIGN_HEATMAP_MARKER")
    end

    it "does not inflate streak from another user's daily logs (trap)" do
      # user_b has 5 consecutive days of 100% adherence ending today.
      user_b_habit = create(:habit, label: "B habit", position: 0, user: user_b)
      user_b_plan = create(:plan, slug: "exercise-b", name: "B exercise", user: user_b)
      5.times do |i|
        date = i.days.ago.to_date
        b_log = create(:daily_log, user: user_b, plan: user_b_plan, date: date)
        create(:habit_entry, daily_log: b_log,
                                     habit: user_b_habit, value: 1)
      end

      # Current.user has ZERO daily_logs and ZERO templates.
      get habits_path

      # Streak must be 0 — the bug would have it read user_b's logs.
      expect(response.body).to match(/<p class="text-xl font-bold leading-none mt-0\.5">0<\/p>/)
    end
  end

  describe "legacy /checklist URL" do
    it "301-redirects to /habits" do
      sign_in_as
      get "/checklist"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/habits")
    end
  end
end
