require "rails_helper"

RSpec.describe "Session sign-out and navigation hygiene", type: :system do
  describe "S5a: Sign-out redirects to sign-in and prevents re-access" do
    it "clears the auth cookie and blocks access to protected routes" do
      alice = create_onboarded_user(email: "alice@example.com")
      bob = create_onboarded_user(email: "bob@example.com")

      # Alice signs in
      using_session("alice") do
        system_sign_in(email: "alice@example.com", password: "password12345")
        expect(page).to have_current_path(root_path)
      end

      # Bob signs in (parallel session, independent cookie jar)
      using_session("bob") do
        system_sign_in(email: "bob@example.com", password: "password12345")
        expect(page).to have_current_path(root_path)
      end

      # Alice navigates to Settings and clicks Sign out
      using_session("alice") do
        visit settings_path
        expect(page).to have_text("Sign out")

        click_button "Sign out"

        # Verify Alice is redirected to sign-in
        expect(page).to have_current_path(new_session_path)
      end

      # Alice tries to visit / — redirected to sign-in again
      using_session("alice") do
        visit root_path
        expect(page).to have_current_path(new_session_path)
      end

      # Bob's parallel session is unaffected — his / still renders his dashboard
      using_session("bob") do
        visit root_path
        expect(page).to have_current_path(root_path)
        expect(page).to have_text("Good day")
      end
    end
  end

  describe "S5b: Browser back button after sign-out blocks access to authed pages" do
    it "prevents back-button navigation to authed routes after sign-out" do
      alice = create_onboarded_user(email: "alice@example.com")
      bob = create_onboarded_user(email: "bob@example.com")

      using_session("alice") do
        system_sign_in(email: "alice@example.com", password: "password12345")
      end

      using_session("bob") do
        system_sign_in(email: "bob@example.com", password: "password12345")
      end

      using_session("alice") do
        # Visit a few pages to build history
        visit root_path
        visit checklist_path
        visit settings_path

        # Sign out
        click_button "Sign out"
        expect(page).to have_current_path(new_session_path)

        # Attempt to navigate back via browser back button
        page.driver.browser.navigate.back

        # Verify that either:
        # 1. The current path is the sign-in page (page redirected), or
        # 2. The page contains no Alice-specific personal data
        # (Rails should prevent access to authed routes and redirect)
        if page.current_path != new_session_path
          # If not redirected, verify Alice's personal data is not present
          expect(page).to have_no_text(alice.email_address)
        else
          expect(page).to have_current_path(new_session_path)
        end
      end

      # Bob's parallel session remains unaffected
      using_session("bob") do
        visit root_path
        expect(page).to have_current_path(root_path)
      end
    end
  end
end
