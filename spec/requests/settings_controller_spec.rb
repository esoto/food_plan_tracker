require "rails_helper"

RSpec.describe SettingsController, type: :request do
  describe "GET /settings" do
    it "renders ok for the authenticated user" do
      user_a = create(:user, password: "password12345")
      sign_in_as(user_a)
      create(:plan, user: user_a)
      get settings_path
      expect(response).to have_http_status(:ok)
    end

    it "excludes another user's plans and goals" do
      user_a = create(:user, password: "password12345")
      sign_in_as(user_a)
      create(:plan, slug: "active", name: "A active", user: user_a)

      other = create(:user)
      create(:plan, slug: "rest", name: "OTHER SETTINGS PLAN", user: other)
      create(:goal, :weight, display_name: "OTHER SETTINGS GOAL", user: other)

      get settings_path

      expect(response.body).not_to include("OTHER SETTINGS PLAN")
      expect(response.body).not_to include("OTHER SETTINGS GOAL")
    end

    describe "with food tracking disabled" do
      it "hides plan macro targets and per-meal targets, keeps goals and account" do
        user_a = create(:user, password: "password12345", food_tracking_enabled: false)
        sign_in_as(user_a)
        create(:plan, slug: "active", user: user_a)
        create(:goal, :weight, user: user_a)

        get settings_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Plan macro targets")
        expect(response.body).not_to include("Per-meal targets")
        expect(response.body).to include("Goal targets")
        expect(response.body).to include("Signed in as")
        expect(response.body).not_to include("To add or remove a plan/goal")
        expect(response.body).to include("To add or remove a goal")
      end
    end

    describe "with food tracking enabled" do
      it "renders plan macro targets, per-meal targets, goals, and account unchanged" do
        user_a = create(:user, password: "password12345", food_tracking_enabled: true)
        sign_in_as(user_a)
        create(:plan, slug: "active", user: user_a)
        create(:goal, :weight, user: user_a)

        get settings_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Plan macro targets")
        expect(response.body).to include("Per-meal targets")
        expect(response.body).to include("Goal targets")
        expect(response.body).to include("Signed in as")
        expect(response.body).to include("To add or remove a plan/goal")
      end
    end
  end
end
