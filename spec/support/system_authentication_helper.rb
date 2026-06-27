module SystemAuthenticationHelper
  def system_sign_in(email:, password:)
    visit new_session_path
    fill_in "Email", with: email
    fill_in "Password", with: password
    click_button "Sign in"
    # Strict landing assertion is safe: request_authentication ignores
    # non-navigational requests (Sec-Fetch-Mode guard), so the service
    # worker's shell precache can no longer pollute the post-login redirect.
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
