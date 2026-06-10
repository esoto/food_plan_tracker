# frozen_string_literal: true

# OAuth provider for the remote MCP endpoint that claude.ai connects to.
# Multi-user: the resource owner is whichever user's session authorizes the
# grant (resolved from the session cookie below). Clients (Claude.ai, Claude
# mobile) register themselves via DCR (RFC 7591) and walk through the
# standard authorization-code-with-PKCE flow.
Doorkeeper.configure do
  orm :active_record

  # Doorkeeper's controllers inherit from Doorkeeper::ApplicationController,
  # which extends ActionController::Base directly — *not* this app's
  # ApplicationController. So our Authentication concern's
  # `before_action :require_authentication` never fires on /oauth/authorize,
  # which means `Current.session` is never populated from the cookie.
  # That left `Current.user` blank here, redirecting every authorize request
  # back to login, looping forever after the user signed in.
  #
  # Resume the session manually before checking Current.user.
  resource_owner_authenticator do
    Current.session ||= Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    Current.user || begin
      session[:return_to_after_authenticating] = request.fullpath
      redirect_to(new_session_path)
    end
  end

  # Tokens last a day; the refresh token (long-lived) lets Claude rotate.
  access_token_expires_in 1.day
  use_refresh_token

  # PKCE is mandatory. `force_pkce` is hard-coded to skip *confidential*
  # clients (Doorkeeper 5.9), so the DCR endpoint registers public clients
  # (`confidential: false`) instead — see app/controllers/oauth/
  # registrations_controller.rb. That makes `force_pkce` actually engage.
  force_pkce

  # Single grant flow: authorization code (with PKCE).
  grant_flows %w[authorization_code]

  # Hash both application secrets and tokens at rest. We never need to
  # display them again (DCR returns the plaintext once at registration;
  # tokens are only ever sent to Claude).
  hash_application_secrets
  hash_token_secrets

  # MCP scope — single scope is fine for a personal connector. Tools
  # do both reads and writes.
  default_scopes :mcp
  enforce_configured_scopes

  # Production redirect URIs are claude.ai callbacks (HTTPS).
  force_ssl_in_redirect_uri !Rails.env.development?

  realm "food_plan_tracker"
end
