require "rails_helper"

RSpec.describe "Invitations", type: :request do
  # A freshly-created (admin-provisioned) user has a random password and no
  # sessions yet — exactly the state an invitee is in.
  let(:user) { create(:user, email_address: "invitee@example.com") }
  let(:token) { user.generate_token_for(:invitation) }

  describe "GET /invitations/:token/edit" do
    it "renders the set-password form for a valid token" do
      get edit_invitation_path(token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Set your password")
    end

    it "redirects a garbage token to login with a generic alert" do
      get edit_invitation_path("not-a-real-token")
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Invitation link is invalid or has expired.")
    end

    it "rejects an expired token" do
      token
      travel_to(4.days.from_now) do
        get edit_invitation_path(token)
        expect(response).to redirect_to(new_session_path)
        expect(flash[:alert]).to eq("Invitation link is invalid or has expired.")
      end
    end

    it "rejects a deactivated user's token" do
      user.update!(deactivated_at: Time.current)
      get edit_invitation_path(token)
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Invitation link is invalid or has expired.")
    end
  end

  describe "PATCH /invitations/:token" do
    it "sets the password, seeds defaults, signs in, and lands on root" do
      patch invitation_path(token), params: { password: "brandnewpass12", password_confirmation: "brandnewpass12" }

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Welcome! Your account is ready.")
      expect(user.reload.authenticate("brandnewpass12")).to be_truthy
      expect(user.plans.count).to eq(3)              # Onboarding::SeedDefaults ran
      expect(user.sessions.count).to eq(1)           # start_new_session_for ran
    end

    # Load-bearing for the salt-bound token: accepting the invite rotates the
    # password salt, so the original token must no longer resolve. Fails if the
    # `password_salt&.last(10)` binding is dropped from generates_token_for.
    it "invalidates the token after it has been used" do
      used = token
      patch invitation_path(used), params: { password: "brandnewpass12", password_confirmation: "brandnewpass12" }

      get edit_invitation_path(used)
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Invitation link is invalid or has expired.")
    end

    it "re-renders with an error when the password is too short" do
      patch invitation_path(token), params: { password: "short", password_confirmation: "short" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("too short")
      expect(user.sessions.count).to eq(0)
    end
  end
end
