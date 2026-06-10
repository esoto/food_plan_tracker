module SystemAuthenticationHelper
  def system_sign_in(email:, password:)
    visit new_session_path
    fill_in "Email", with: email
    fill_in "Password", with: password
    click_button "Sign in"
    # Don't assert the post-login landing path: the PWA service worker's
    # shell precache (which includes authed routes like /progress) can run
    # while logged out and pollute return_to_after_authenticating, making
    # the redirect target nondeterministic across examples. Tracked in
    # Linear PER-575. Assert we're signed in, then navigate explicitly.
    expect(page).to have_no_current_path(new_session_path)
    visit root_path
    expect(page).to have_current_path(root_path)
  end

  def create_onboarded_user(email:, password: "password12345")
    user = create(:user, email_address: email, password: password, password_confirmation: password)
    Onboarding::SeedDefaults.call(user)
    user
  end
end

RSpec.configure do |config|
  config.include SystemAuthenticationHelper, type: :system
end
