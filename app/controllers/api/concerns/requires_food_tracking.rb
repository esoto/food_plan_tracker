module Api
  module Concerns
    module RequiresFoodTracking
      extend ActiveSupport::Concern

      included do
        before_action :require_food_tracking!
      end

      private

      def require_food_tracking!
        return if Current.user.food_tracking_enabled?

        render json: { error: "food_tracking_disabled" }, status: :forbidden
      end
    end
  end
end
