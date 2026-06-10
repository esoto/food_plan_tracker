require "rails_helper"

RSpec.describe "Two-user parallel session isolation", type: :system do
  describe "S3: Alice and Bob operate simultaneously with browser cookie isolation" do
    it "prevents cross-user data leakage via two independent browser cookie jars" do
      # Create two users with onboarded defaults (plans, goals, etc.)
      alice = create_onboarded_user(email: "alice@example.com")
      bob = create_onboarded_user(email: "bob@example.com")

      # Alice and Bob sign in simultaneously via independent Capybara sessions
      # (independent cookie jars, separate WebDriver instances under the hood)
      using_session("alice") do
        system_sign_in(email: "alice@example.com", password: "password12345")
      end

      using_session("bob") do
        system_sign_in(email: "bob@example.com", password: "password12345")
      end

      # Alice creates a supplement via the real form
      using_session("alice") do
        visit settings_supplements_path
        expect(page).to have_link("+ New supplement")

        click_link "+ New supplement"
        expect(page).to have_current_path(new_settings_supplement_path)

        fill_in "Name", with: "AliceBrowserSupp"
        fill_in "Dose", with: "1 capsule"
        # Check the first time slot (Morning)
        all("input[name='time_slots[]']").first.click
        click_button "Add supplement"

        expect(page).to have_current_path(settings_supplements_path)
        expect(page).to have_text("AliceBrowserSupp")
      end

      # Bob visits his supplements page — must NOT see Alice's supplement
      using_session("bob") do
        visit settings_supplements_path
        expect(page).to have_link("+ New supplement")
        # Positive control: Bob's empty state rendered — the negative below
        # can't pass vacuously on a blank/error page.
        expect(page).to have_text("No active supplements yet")
        expect(page).to have_no_text("AliceBrowserSupp")
      end

      # Bob creates his own supplement
      using_session("bob") do
        click_link "+ New supplement"
        expect(page).to have_current_path(new_settings_supplement_path)

        fill_in "Name", with: "BobBrowserSupp"
        fill_in "Dose", with: "2 capsules"
        all("input[name='time_slots[]']").first.click
        click_button "Add supplement"

        expect(page).to have_current_path(settings_supplements_path)
        expect(page).to have_text("BobBrowserSupp")
      end

      # Alice revisits her supplements page — sees only her own
      using_session("alice") do
        visit settings_supplements_path
        expect(page).to have_text("AliceBrowserSupp")
        expect(page).to have_no_text("BobBrowserSupp")
      end

      # Both navigate to /checklist independently
      using_session("alice") do
        visit checklist_path
        expect(page).to have_text("Daily habits")
      end

      using_session("bob") do
        visit checklist_path
        expect(page).to have_text("Daily habits")
      end
    end
  end
end
