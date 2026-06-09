require "rails_helper"

RSpec.describe TodayController, type: :request do
  let!(:user) { create(:user) }

  before do
    create(:plan, slug: "exercise", name: "Exercise day", user: user)
    create(:plan, slug: "active",   name: "Active day",   user: user)
    create(:plan, slug: "rest",     name: "Rest day",     user: user)
    sign_in_as(user)
  end

  describe "GET /" do
    it "renders only goals that have at least one biomarker reading" do
      tracked   = create(:goal, :weight, :with_measurement, measurement_value: 90.0, user: user)
      untracked = create(:goal, user: user)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(tracked.display_name)
      expect(response.body).not_to include(untracked.display_name)
    end

    it "renders the '+ Log a biomarker' CTA when at least one goal has no readings" do
      create(:goal, :weight, :with_measurement, measurement_value: 90.0, user: user)
      create(:goal, user: user)

      get root_path

      expect(response.body).to include("+ Log a biomarker")
      expect(response.body).to include("1 untracked")
    end

    it "hides the CTA when every goal has at least one reading" do
      create(:goal, :weight,   :with_measurement, measurement_value: 90.0, user: user)
      create(:goal, :preserve, :with_measurement, measurement_value: 67.0, user: user)

      get root_path

      expect(response.body).not_to include("+ Log a biomarker")
    end

    describe "fibrotina_due? cross-tenant (PER-556 helper)" do
      it "does not consider another user's Fibrotina supplement" do
        user_a = create(:user, password: "password")
        sign_in_as(user_a)
        create(:plan, slug: "active", user: user_a)
        other = create(:user)
        create(:supplement, name: "Fibrotina (fenofibrate)", user: other)

        travel_to Time.zone.local(2026, 4, 25, 19, 30) do  # inside the fibrotina window
          get root_path
        end

        expect(response.body).not_to include("Fibrotina time")
      end

      it "does consider the current user's Fibrotina supplement" do
        user_a = create(:user, password: "password")
        sign_in_as(user_a)
        create(:plan, slug: "active", user: user_a)
        create(:supplement, name: "Fibrotina (fenofibrate)", user: user_a)

        travel_to Time.zone.local(2026, 4, 25, 19, 30) do  # inside the fibrotina window
          get root_path
        end

        expect(response.body).to include("Fibrotina time")
      end
    end

    describe "weight goal scoping" do
      it "displays only the current user's weight goal, not another user's (PER-570)" do
        # Create user_b's weight goal FIRST with distinctive target (foreign record comes first)
        user_b = create(:user)
        foreign_weight_goal = create(:goal, :weight, target_value: 987.5, user: user_b)

        # Create current user's weight goal
        user_a = create(:user, password: "password")
        sign_in_as(user_a)
        create(:plan, slug: "active", user: user_a)
        own_weight_goal = create(:goal, :weight, target_value: 65.0, user: user_a)

        get root_path

        expect(response).to have_http_status(:ok)
        # Own goal's target value should be visible (exact partial output)
        expect(response.body).to include("Goal: 65.0 kg")
        # Foreign goal's target value should NOT be visible
        expect(response.body).not_to include("987.5")
        # Own goal id should be in the hidden field
        expect(response.body).to include(%Q(value="#{own_weight_goal.id}"))
        # Foreign goal id should NOT be in the hidden field
        expect(response.body).not_to include(%Q(value="#{foreign_weight_goal.id}"))
      end

      it "renders weight section gracefully when current user has no weight goal" do
        user_b = create(:user)
        create(:goal, :weight, target_value: 987.5, user: user_b)

        user_a = create(:user, password: "password")
        sign_in_as(user_a)
        create(:plan, slug: "active", user: user_a)

        get root_path

        expect(response).to have_http_status(:ok)
        # Foreign goal value should not appear
        expect(response.body).not_to include("987.5")
        # Weight input section should still render
        expect(response.body).to include("weight")
      end
    end

    describe "fibrotina reminder banner" do
      it "does not show banner for another user's Fibrotina supplement (PER-570 helper scoping)" do
        # Create user_b's Fibrotina FIRST (foreign record comes first)
        user_b = create(:user)
        create(:supplement, name: "Fibrotina B12", user: user_b)

        # Current user has NO fibrotina
        user_a = create(:user, password: "password")
        sign_in_as(user_a)
        create(:plan, slug: "active", user: user_a)

        travel_to Time.zone.local(2026, 4, 25, 19, 30) do  # inside fibrotina window
          get root_path
        end

        expect(response.body).not_to include("Fibrotina time")
      end

      it "shows banner with correct scoped supplement id when both users have Fibrotina (PER-570 partial scoping)" do
        # Create user_b's Fibrotina FIRST (foreign record comes first)
        user_b = create(:user)
        foreign_fibrotina = create(:supplement, name: "Fibrotina (fenofibrate)", user: user_b)

        # Create current user's Fibrotina
        user_a = create(:user, password: "password")
        sign_in_as(user_a)
        create(:plan, slug: "active", user: user_a)
        own_fibrotina = create(:supplement, name: "Fibrotina (fenofibrate)", user: user_a)

        travel_to Time.zone.local(2026, 4, 25, 19, 30) do  # inside fibrotina window
          get root_path
        end

        expect(response).to have_http_status(:ok)
        # Banner should be present
        expect(response.body).to include("Fibrotina time")
        # Form should post with OWN supplement id
        expect(response.body).to include("supplement_id=#{own_fibrotina.id}")
        # Form should NOT post with foreign supplement id
        expect(response.body).not_to include("supplement_id=#{foreign_fibrotina.id}")
      end

      it "does not show banner when current user's Fibrotina already taken today" do
        travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 19, 30) do
          user_a = create(:user, password: "password")
          sign_in_as(user_a)
          create(:plan, slug: "active", user: user_a)
          fibrotina = create(:supplement, name: "Fibrotina (fenofibrate)", user: user_a)

          # Create a completion for today
          daily_log = DailyLog.today(user_a)
          create(:supplement_completion, daily_log: daily_log, supplement: fibrotina)

          get root_path

          expect(response.body).not_to include("Fibrotina time")
        end
      end
    end

    describe "cross-tenant isolation" do
      it "excludes another user's plans, goals, and weight entries" do
        user_a = create(:user, password: "password")
        sign_in_as(user_a)
        create(:plan, slug: "active", name: "A active", user: user_a)

        other = create(:user)
        create(:plan, slug: "rest", name: "OTHER REST PLAN", user: other)
        create(:goal, :weight, :with_measurement, display_name: "OTHER WEIGHT GOAL", user: other)

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("OTHER REST PLAN")
        expect(response.body).not_to include("OTHER WEIGHT GOAL")
      end
    end
  end
end
