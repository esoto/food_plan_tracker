require "rails_helper"

# The PWA service worker precaches authed shell routes; while signed out
# those fetches (Sec-Fetch-Mode: no-cors) hit request_authentication and
# previously stored return_to_after_authenticating — hijacking the user's
# next sign-in to whichever route the precache touched last (/progress).
RSpec.describe "return_to is navigation-only", type: :request do
  let!(:user) { create(:user) }

  it "a non-navigational request while signed out does not hijack the post-login redirect" do
    get progress_path, headers: { "Sec-Fetch-Mode" => "no-cors" }
    expect(response).to redirect_to(new_session_path)

    post session_path, params: { email_address: user.email_address, password: "password12345" }
    expect(response).to redirect_to(root_url)
  end

  it "a real browser navigation still returns the user to where they were going" do
    get progress_path, headers: { "Sec-Fetch-Mode" => "navigate" }
    expect(response).to redirect_to(new_session_path)

    post session_path, params: { email_address: user.email_address, password: "password12345" }
    expect(response).to redirect_to(progress_url)
  end

  it "requests without Sec-Fetch-Mode (non-browser clients, old agents) keep the return_to behavior" do
    get progress_path
    post session_path, params: { email_address: user.email_address, password: "password12345" }
    expect(response).to redirect_to(progress_url)
  end
end
