require "rails_helper"

RSpec.describe "User Registration", type: :system do
  describe "S1: Happy path registration" do
    it "creates a user, initializes plans, and logs to home page" do
      visit root_path
      expect(page).to have_current_path(new_session_path)

      click_link "Sign up"
      expect(page).to have_current_path(new_registration_path)

      fill_in "user[email_address]", with: "alice@example.com"
      fill_in "user[password]", with: "password12345"
      fill_in "user[password_confirmation]", with: "password12345"
      click_button "Sign up"

      expect(page).to have_text("Exercise day")
      expect(page).to have_current_path(root_path)
      expect(page).to have_text("Active day")
      expect(page).to have_text("Rest day")

      # The weight card renders in its empty state. NOTE: a fresh user has
      # no weight goal, so submitting this form 404s (goal_id is nil) —
      # real first-run product gap tracked in the Obsidian note 'Food Plan
      # Tracker — Post-Epic Follow-ups' (Linear issue limit reached); the logging
      # journey will be browser-covered once it's fixed.
      expect(page).to have_text("TODAY'S WEIGHT")
      expect(page).to have_text("— kg")

      expect(User.count).to eq 1
      expect(Plan.count).to eq 3
    end
  end

  describe "S2a: Duplicate email validation" do
    it "shows error and stays on registration page" do
      create(:user, email_address: "alice@example.com")

      visit new_registration_path
      fill_in "user[email_address]", with: "alice@example.com"
      fill_in "user[password]", with: "password12345"
      fill_in "user[password_confirmation]", with: "password12345"
      click_button "Sign up"

      expect(page).to have_current_path(new_registration_path)
      expect(page).to have_selector(".bg-red-50")
      expect(page).to have_text("has already been taken")
    end
  end

  describe "S2b: Short password validation" do
    it "shows error message" do
      visit new_registration_path
      fill_in "user[email_address]", with: "bob@example.com"
      fill_in "user[password]", with: "short"
      fill_in "user[password_confirmation]", with: "short"
      click_button "Sign up"

      expect(page).to have_selector(".bg-red-50")
      expect(page).to have_text("too short")
    end
  end

  describe "S2c: Password confirmation mismatch" do
    it "shows error message" do
      visit new_registration_path
      fill_in "user[email_address]", with: "carol@example.com"
      fill_in "user[password]", with: "password12345"
      fill_in "user[password_confirmation]", with: "password12346"
      click_button "Sign up"

      expect(page).to have_selector(".bg-red-50")
      expect(page).to have_text("doesn't match")
    end
  end
end
