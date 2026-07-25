require "rails_helper"

RSpec.describe "Invite-only onboarding", type: :system do
  describe "S1: Requesting access" do
    it "lets a visitor submit an access request from the sign-in page" do
      visit new_session_path
      click_link "Request access"
      expect(page).to have_current_path(new_access_request_path)

      fill_in "access_request[email_address]", with: "hopeful@example.com"
      fill_in "access_request[message]", with: "I'd love to try this."
      click_button "Request access"

      # Enumeration-safe generic confirmation, back on the sign-in page.
      expect(page).to have_current_path(new_session_path)
      expect(page).to have_text("you'll receive an email invitation")
      expect(AccessRequest.find_by(email_address: "hopeful@example.com")).to be_present
    end
  end

  describe "S2: Accepting an invitation" do
    it "sets a password, provisions defaults, and lands on the dashboard" do
      user = create(:user, email_address: "invitee@example.com")
      token = user.generate_token_for(:invitation)

      visit edit_invitation_path(token)
      expect(page).to have_text("Set your password")

      fill_in "password", with: "freshpassword12"
      fill_in "password_confirmation", with: "freshpassword12"
      click_button "Save"

      expect(page).to have_current_path(root_path)
      expect(page).to have_text("Exercise day")
      expect(user.reload.plans.count).to eq(3)
    end
  end

  describe "S3: A used invitation link is dead" do
    it "shows the generic alert when the token has already been redeemed" do
      user = create(:user, email_address: "invitee@example.com")
      token = user.generate_token_for(:invitation)
      user.update!(password: "alreadysetpass12")   # rotates the salt the token is bound to

      visit edit_invitation_path(token)
      expect(page).to have_current_path(new_session_path)
      expect(page).to have_text("invalid or has expired")
    end
  end
end
