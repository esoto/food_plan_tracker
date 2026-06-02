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
