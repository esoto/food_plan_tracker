require "rails_helper"

# Regression coverage for the OAuth-blocked-by-CSP bug. The browser applies
# `form-action` to the entire navigation chain after a form POST — including
# any 302 redirect — so if `/oauth/authorize` redirects to claude.ai with the
# auth code, the browser silently refuses to follow unless claude.ai is
# whitelisted in `form-action`.
RSpec.describe "Content-Security-Policy header", type: :request do
  it "whitelists claude.ai and claude.com in form-action so the OAuth redirect can follow" do
    get "/up"

    csp = response.headers["Content-Security-Policy"]
    expect(csp).to be_present
    expect(csp).to match(/form-action [^;]*\bhttps:\/\/claude\.ai\b/)
    expect(csp).to match(/form-action [^;]*\bhttps:\/\/claude\.com\b/)
    expect(csp).to match(/form-action [^;]*'self'/)
  end
end
