module Api
  module V1
    class PlansController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        render json: { plans: Plan.ordered.map { |p| serialize_plan(p) } }
      end
    end
  end
end
