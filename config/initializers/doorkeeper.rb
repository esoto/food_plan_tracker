# frozen_string_literal: true

# OAuth provider for the remote MCP endpoint that claude.ai connects to.
# Single-user app: the resource owner is always the only user. Clients
# (Claude.ai, Claude mobile) register themselves via DCR (RFC 7591) and
# walk through the standard authorization-code-with-PKCE flow.
Doorkeeper.configure do
  orm :active_record

  resource_owner_authenticator do
    if Current.user
      Current.user
    else
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
