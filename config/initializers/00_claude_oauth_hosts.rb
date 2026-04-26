# Single source of truth for the Claude hosts the OAuth dance is allowed
# to terminate at. Two callers consume this:
#
#   * DCR endpoint (`Oauth::RegistrationsController`) restricts the
#     `redirect_uris` claude.ai may register at /oauth/register.
#   * CSP initializer (`content_security_policy.rb`) whitelists those
#     same origins under `form-action` so the post-consent 302 is not
#     blocked by the browser.
#
# Filename prefixed `00_` so it loads before `content_security_policy.rb`.
module ClaudeOauth
  ALLOWED_HOSTS   = %w[claude.ai claude.com].freeze
  ALLOWED_ORIGINS = ALLOWED_HOSTS.map { |h| "https://#{h}" }.freeze
end
