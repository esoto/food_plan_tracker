require "rails_helper"

RSpec.describe "Food-disabled user journey", type: :system do
  it "lets an admin disable a member's food tracking, and the member still logs weight and habits while food pages redirect away" do
    admin = create(:user, :admin, email_address: "admin@example.com",
                                   password: "password12345", password_confirmation: "password12345")
    member = create_onboarded_user(email: "member@example.com")
    member.update!(food_tracking_enabled: true)
    create(:goal, :weight, user: member)
    create(:habit, user: member, label: "Morning walk", description: "30 min", icon: "🚶")

    using_session("admin") do
      system_sign_in(email: "admin@example.com", password: "password12345")
      visit admin_root_path
      expect(page).to have_text(member.email_address)

      # Unique on the page: the admin defaults to food_tracking_enabled
      # false, so only member's row shows "Disable food tracking".
      click_button "Disable food tracking"

      expect(page).to have_text("Disabled food tracking for #{member.email_address}.")
    end

    expect(member.reload.food_tracking_enabled?).to be false

    using_session("member") do
      system_sign_in(email: "member@example.com", password: "password12345")

      within("nav") do
        expect(page).to have_link("Today")
        expect(page).to have_link("Habits")
        expect(page).to have_link("Progress")
        expect(page).to have_link("Supplements")
        expect(page).to have_no_link("Menu")
        expect(page).to have_no_link("Foods")
      end

      fill_in "Enter your weight", with: "72.5"
      click_button "Log"
      expect(page).to have_text("72.5")
      expect(page).to have_no_text("— kg")

      visit habits_path
      within("form[action*='habit_entries']") do
        expect(page).to have_text("Morning walk")
        click_button "Morning walk"
      end
      within("form[action*='habit_entries']") do
        expect(page).to have_css("div.bg-emerald-500")
      end

      within("nav") { click_link "Progress" }
      expect(page).to have_current_path(progress_path)

      visit menu_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_text("Food tracking is not enabled for your account.")
    end
  end
end
