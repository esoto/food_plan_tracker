module Oauth
  # RFC 7591 — Dynamic Client Registration. Claude.ai POSTs the metadata
  # for a new client (its callback URL, a friendly name) and we hand back
  # the client_id it will use for the auth-code exchange.
  #
  # Two defenses anchor the security of this endpoint:
  #
  # 1. Whitelisted redirect_uris (claude.ai / claude.com only). Without
  #    this, an attacker could register a client pointing at attacker.com
  #    and trick the user (already logged in) into approving a consent
  #    screen branded "Claude" that delivers tokens off-domain.
  #
  # 2. Public clients (`confidential: false`) so Doorkeeper's `force_pkce`
  #    actually engages. `force_pkce` is hard-coded to skip confidential
  #    clients, so we must opt out of the client_secret model entirely
  #    and rely on PKCE for proof-of-possession of the auth code. This
  #    matches OAuth 2.1 best practice for clients that can't securely
  #    store secrets (mobile, browser-based, MCP connectors).
  #
  # The endpoint itself is unauthenticated (clients have no creds yet at
  # registration time) and rate-limited 10/hour/IP.
  class RegistrationsController < ActionController::API
    ALLOWED_REDIRECT_HOSTS = %w[claude.ai claude.com].freeze

    rate_limit to: 10, within: 1.hour,
               by: -> { request.remote_ip },
               with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }

    def create
      uris = Array(params[:redirect_uris]).reject(&:blank?)
      return render(json: { error: "invalid_redirect_uri" }, status: :bad_request) if uris.empty?

      unless uris.all? { |uri| allowed_redirect_uri?(uri) }
        return render(json: {
          error:             "invalid_redirect_uri",
          error_description: "redirect_uris must be HTTPS on #{ALLOWED_REDIRECT_HOSTS.join(' or ')}"
        }, status: :bad_request)
      end

      app = Doorkeeper::Application.create!(
        name:         params[:client_name].presence || "MCP Client",
        redirect_uri: uris.join("\n"),
        scopes:       "mcp",
        confidential: false
      )

      render json: {
        client_id:                  app.uid,
        client_id_issued_at:        app.created_at.to_i,
        client_name:                app.name,
        redirect_uris:              uris,
        grant_types:                %w[authorization_code refresh_token],
        response_types:             %w[code],
        token_endpoint_auth_method: "none",
        scope:                      "mcp"
      }, status: :created
    end

    private

    def allowed_redirect_uri?(uri)
      parsed = URI.parse(uri)
      parsed.is_a?(URI::HTTPS) && ALLOWED_REDIRECT_HOSTS.include?(parsed.host)
    rescue URI::InvalidURIError
      false
    end
  end
end
