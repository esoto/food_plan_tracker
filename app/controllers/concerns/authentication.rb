module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      return unless cookies.signed[:session_id]

      session = Session.find_by(id: cookies.signed[:session_id])
      return session unless session&.user&.deactivated?

      # A deactivated user's live cookie must not resume: tear the session
      # down so a later reactivation still requires a fresh sign-in.
      session.destroy
      cookies.delete(:session_id)
      nil
    end

    def request_authentication
      # Only remember the destination for real browser navigations. The PWA
      # service worker precaches authed shell routes; those fetches send
      # Sec-Fetch-Mode: no-cors and must not hijack the post-login redirect.
      # Known tradeoff: a Turbo Drive visit after mid-session expiry sends
      # Sec-Fetch-Mode: cors, so that rare flow loses its return-to (lands
      # on root). Strictly smaller than the precache hijack this prevents.
      if request.headers["Sec-Fetch-Mode"].nil? || request.headers["Sec-Fetch-Mode"] == "navigate"
        session[:return_to_after_authenticating] = request.url
      end
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax, secure: Rails.env.production? }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
