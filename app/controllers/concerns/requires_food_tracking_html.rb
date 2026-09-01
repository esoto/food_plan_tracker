module RequiresFoodTrackingHtml
  extend ActiveSupport::Concern

  included do
    before_action :require_food_tracking!
  end

  private

  def require_food_tracking!
    return if Current.user.food_tracking_enabled?

    redirect_to root_path, alert: "Food tracking is not enabled for your account."
  end
end
