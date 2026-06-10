require "rails_helper"

RSpec.describe "Fresh user smoke test (PER-572)", type: :request do
  let!(:other_user) do
    user = create(:user)
    create(:plan, slug: "active", name: "FOREIGN_SMOKE_MARKER_PLAN", target_kcal: 2075, user: user)
    create(:supplement, name: "FOREIGN_SMOKE_MARKER_SUPPLEMENT", user: user)
    create(:checklist_template, label: "FOREIGN_SMOKE_MARKER_HABIT", user: user)
    create(:goal, :weight, display_name: "FOREIGN_SMOKE_MARKER_GOAL", user: user)
    user
  end

  let!(:fresh_user) { create(:user) }

  before do
    Onboarding::SeedDefaults.call(fresh_user)
    sign_in_as(fresh_user)
  end

  describe "all HTML surfaces render without error and exclude foreign user data" do
    it "GET / renders with 200 and excludes other user's plan" do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_PLAN")
    end

    it "GET /menu renders with 200 and excludes other user's plan" do
      get menu_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_PLAN")
    end

    it "GET /exchanges renders with 200 and excludes other user's supplement" do
      get exchanges_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_SUPPLEMENT")
    end

    it "GET /supplements renders with 200 and excludes other user's supplement" do
      get supplements_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_SUPPLEMENT")
    end

    it "GET /checklist renders with 200 and excludes other user's habit" do
      get checklist_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_HABIT")
    end

    it "GET /progress renders with 200 and excludes other user's goal" do
      get progress_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_GOAL")
    end

    it "GET /settings renders with 200 and excludes other user's data" do
      get settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_SUPPLEMENT")
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_HABIT")
    end

    it "GET /notifications renders with 200 and excludes other user's data" do
      get notifications_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER")
    end

    it "GET /settings/supplements renders with 200 and excludes other user's supplement" do
      get settings_supplements_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_SUPPLEMENT")
    end

    it "GET /settings/supplements/archived renders with 200" do
      get archived_settings_supplements_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_SUPPLEMENT")
    end

    it "GET /settings/habits renders with 200 and excludes other user's habit" do
      get settings_habits_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_HABIT")
    end

    it "GET /settings/habits/archived renders with 200" do
      get archived_settings_habits_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_HABIT")
    end

    it "GET /days/:date (past date) renders with 200 and excludes other user's data" do
      past_date = Date.current - 3
      daily_log = DailyLog.create!(date: past_date, plan: fresh_user.plans.find_by!(slug: Plan::ACTIVE_SLUG), user: fresh_user)

      get day_path(past_date)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_PLAN")
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_SUPPLEMENT")
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_HABIT")
      expect(response.body).not_to include("FOREIGN_SMOKE_MARKER_GOAL")
    end
  end
end
