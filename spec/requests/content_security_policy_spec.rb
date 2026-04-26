require "rails_helper"

# Regression coverage for the OAuth-blocked-by-CSP bug. The browser applies
# `form-action` to the entire navigation chain after a form POST — including
# any 302 redirect — so if `/oauth/authorize` redirects to claude.ai with the
# auth code, the browser silently refuses to follow unless claude.ai is
# whitelisted in `form-action`. Hitting /oauth/authorize directly (rather
# than /up) locks the assertion to the actual bug surface.
RSpec.describe "Content-Security-Policy form-action", type: :request do
  it "lists exactly self + the configured Claude origins on the OAuth authorize endpoint" do
    get "/oauth/authorize" # 302 to /session/new with the CSP header attached

    csp = response.headers["Content-Security-Policy"]
    expect(csp).to be_present

    # Parse the directive into tokens so an off-domain prefix like
    # `https://claude.ai.evil.com` cannot pass a regex word-boundary check.
    form_action = csp[/form-action ([^;]+)/, 1].to_s.split

    expect(form_action).to contain_exactly(
      "'self'",
      *ClaudeOauth::ALLOWED_ORIGINS
    )
  end
end
