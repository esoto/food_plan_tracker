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
  end
end
