# Discovery endpoints that let claude.ai's connector wizard find the
# OAuth provider and protected MCP resource without manual configuration
# beyond the entry URL.
class WellKnownController < ActionController::API
  def authorization_server
    base = base_url
    render json: {
      issuer:                                     base,
      authorization_endpoint:                     "#{base}/oauth/authorize",
      token_endpoint:                             "#{base}/oauth/token",
      registration_endpoint:                      "#{base}/oauth/register",
      revocation_endpoint:                        "#{base}/oauth/revoke",
      response_types_supported:                   %w[code],
      grant_types_supported:                      %w[authorization_code refresh_token],
      code_challenge_methods_supported:           %w[S256],
      token_endpoint_auth_methods_supported:      %w[client_secret_basic client_secret_post],
      scopes_supported:                           %w[mcp]
    }
  end

  def protected_resource
    base = base_url
    render json: {
      resource:               "#{base}/mcp",
      authorization_servers:  [ base ],
      scopes_supported:       %w[mcp],
      bearer_methods_supported: %w[header]
    }
  end

  private

  def base_url
    "#{request.protocol}#{request.host_with_port}"
  end
end
