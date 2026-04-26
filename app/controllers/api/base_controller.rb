module Api
  class BaseController < ActionController::API
    before_action :authenticate_token!

    rescue_from ActiveRecord::RecordNotFound,    with: :not_found
    rescue_from ActiveRecord::RecordInvalid,     with: :unprocessable
    rescue_from ActionController::ParameterMissing, with: :bad_request
    rescue_from Date::Error,                     with: :bad_date

    private

    def authenticate_token!
      provided = request.headers["Authorization"].to_s.sub(/^Bearer /, "")
      token = ApiToken.authenticate(provided)
      if token
        token.touch_used!
        @current_api_token = token
      else
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end

    def daily_log_for(date_param)
      date = date_param.present? ? Date.parse(date_param.to_s) : Date.current
      DailyLog.for(date)
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
  end
end
