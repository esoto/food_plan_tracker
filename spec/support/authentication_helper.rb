module AuthenticationHelper
  def sign_in_as(user = nil)
    user ||= create(:user, password: "password12345")
    post session_url, params: { email_address: user.email_address, password: "password12345" }
    Current.user = user
    user
  end
end
