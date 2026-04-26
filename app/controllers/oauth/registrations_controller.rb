module Oauth
  # RFC 7591 — Dynamic Client Registration. Claude.ai POSTs the metadata
  # for a new client (its callback URL, a friendly name) and we hand back
  # the client_id/client_secret it will use for the auth-code exchange.
  #
  # The endpoint is intentionally unauthenticated: clients have no
  # credentials yet at registration time. We rate-limit aggressively to
  # bound spam, and Doorkeeper's PKCE requirement plus our consent screen
  # mean a stolen client_id alone cannot mint tokens.
  class RegistrationsController < ActionController::API
    rate_limit to: 10, within: 1.hour,
               by: -> { request.remote_ip },
               with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }

    def create
      uris = Array(params[:redirect_uris]).reject(&:blank?)
      return render(json: { error: "invalid_redirect_uri" }, status: :bad_request) if uris.empty?

      app = Doorkeeper::Application.create!(
        name:         params[:client_name].presence || "MCP Client",
        redirect_uri: uris.join("\n"),
        scopes:       "mcp",
        confidential: true
      )

      # Doorkeeper hashes secrets at rest, but exposes the plaintext on
      # the in-memory instance immediately after create — that's the only
      # moment we can return it to the caller.
      render json: {
        client_id:                  app.uid,
        client_secret:              app.plaintext_secret,
        client_id_issued_at:        app.created_at.to_i,
        client_name:                app.name,
        redirect_uris:              uris,
        grant_types:                %w[authorization_code refresh_token],
        response_types:             %w[code],
        token_endpoint_auth_method: "client_secret_basic",
        scope:                      "mcp"
      }, status: :created
    end
  end
end
