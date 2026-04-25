module AuthenticationHelper
  def sign_in_as(user = nil)
    user ||= create(:user, password: "password")
    post session_url, params: { email_address: user.email_address, password: "password" }
    user
  end
end
