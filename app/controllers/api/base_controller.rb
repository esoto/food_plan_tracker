module Api
  class BaseController < ActionController::API
    # 60 attempts/min/IP — well above any legitimate MCP/PWA client traffic
    # but bounds online brute-force noise and prevents an attacker from using
    # the auth path as a write amplifier (every successful auth bumps
    # api_tokens.last_used_at, so cheap write throttling matters too).
    rate_limit to: 60, within: 1.minute,
               by: -> { request.remote_ip },
               with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }

    before_action :authenticate_token!

    rescue_from ActiveRecord::RecordNotFound,    with: :not_found
    rescue_from ActiveRecord::RecordInvalid,     with: :unprocessable
    rescue_from ActionController::ParameterMissing, with: :bad_request
    # Date::Error is a subclass of ArgumentError (Ruby 3.3+) — rescue_from
    # matches the most-recently-registered handler first, so ArgumentError
    # MUST be registered before Date::Error or it would swallow date parse
    # failures and downgrade their response from 400 to 422.
    rescue_from ArgumentError,                   with: :invalid_argument
    rescue_from Date::Error,                     with: :bad_date
    rescue_from HabitEntry::InvalidValue,        with: :invalid_argument

    private

    def authenticate_token!
      provided = request.headers["Authorization"].to_s.sub(/^Bearer /, "")
      token = ApiToken.authenticate(provided)
      # A deactivated owner's token is treated as no token at all: drop into
      # the 401 branch byte-identically without touching last_used_at.
      token = nil if token&.user&.deactivated?
      if token
        token.touch_used!
        @current_api_token = token
        Current.user = token.user
      else
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end

    def daily_log_for(date_param)
      date = date_param.present? ? Date.parse(date_param.to_s) : Date.current
      DailyLog.for(Current.user, date)
    end

    def not_found
      render json: { error: "not_found" }, status: :not_found
    end

    def unprocessable(error)
      render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    def bad_request(error)
      render json: { error: error.message }, status: :bad_request
    end

    def bad_date
      render json: { error: "invalid date (expected YYYY-MM-DD)" }, status: :bad_request
    end

    def invalid_argument(error)
      render json: { error: error.message }, status: :unprocessable_entity
    end
  end
end
