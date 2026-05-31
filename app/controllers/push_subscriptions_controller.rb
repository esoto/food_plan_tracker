class PushSubscriptionsController < ApplicationController
  # Browsers POST a JSON body shaped like
  #   { endpoint:, keys: { p256dh:, auth: } }
  # which is what `pushManager.subscribe(...).toJSON()` produces.
  skip_before_action :verify_authenticity_token, only: %i[create destroy]

  def create
    sub = PushSubscription.for_user(Current.user).find_or_initialize_by(endpoint: params.require(:endpoint))
    sub.p256dh_key = params.require(:keys).require(:p256dh)
    sub.auth_key   = params.require(:keys).require(:auth)
    sub.user_agent = request.user_agent.to_s.first(255)
    sub.save!

    render json: { ok: true }, status: :created
  rescue ActiveRecord::RecordNotUnique
    render json: { error: "endpoint already registered" }, status: :conflict
  end

  def destroy
    PushSubscription.for_user(Current.user).where(endpoint: params.require(:endpoint)).destroy_all
    head :no_content
  end

  def test
    return head(:service_unavailable) unless PushNotifier.configured?

    result = PushNotifier.broadcast(
      title: "Food Tracker test",
      body:  "If you can read this, push reminders are working.",
      url:   "/",
      user:  Current.user
    )
    redirect_to settings_path, notice: "Test push sent (#{result[:sent]} delivered, #{result[:pruned]} stale subs pruned)."
  end
end
