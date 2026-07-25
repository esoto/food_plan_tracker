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

  describe "POST /session for a deactivated account" do
    it "rejects the correct password with the same generic alert as a wrong password" do
      post session_path, params: { email_address: user.email_address, password: "wrong-password-here" }
      wrong_password_alert = flash[:alert]
      expect(wrong_password_alert).to be_present

      user.update!(deactivated_at: Time.current)
      post session_path, params: { email_address: user.email_address, password: "correcthorsebatterystaple" }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq(wrong_password_alert)
      expect(Session.where(user: user).count).to eq(0)
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

    it "flashes 'Signed out.' on the resulting login page" do
      post session_path, params: { email_address: user.email_address, password: "correcthorsebatterystaple" }
      delete session_path

      expect(flash[:notice]).to eq("Signed out.")
    end
  end

  describe "GET /settings (Account section)" do
    it "renders the Sign out button when authenticated" do
      post session_path, params: { email_address: user.email_address, password: "correcthorsebatterystaple" }

      get settings_path

      expect(response.body).to include("Sign out")
      expect(response.body).to include(user.email_address)
    end
  end
end
