require "rails_helper"

RSpec.describe SessionsController, type: :request do
  let!(:user) { User.create!(email_address: "test@example.com", password: "correcthorsebatterystaple") }

  describe "GET /session/new" do
    it "renders the login form when unauthenticated" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in")
    end

    it "redirects to root when already authenticated" do
      post session_path, params: { email_address: user.email_address, password: "correcthorsebatterystaple" }

      get new_session_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /session" do
    it "terminates the session and redirects to the login page" do
      post session_path, params: { email_address: user.email_address, password: "correcthorsebatterystaple" }
      expect(Session.where(user: user).count).to eq(1)

      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(Session.where(user: user).count).to eq(0)
    end

    it "the next request after logout requires re-auth" do
      post session_path, params: { email_address: user.email_address, password: "correcthorsebatterystaple" }
      delete session_path

      get root_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
