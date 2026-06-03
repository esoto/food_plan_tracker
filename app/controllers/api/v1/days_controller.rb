module Api
  module V1
    class DaysController < Api::BaseController
      include Api::Concerns::DaySerializer

      def show
        render json: serialize_day(daily_log_for(params[:date]))
      end

      def update_plan
        log = daily_log_for(params[:date])
        plan = Plan.find_by_slug!(params.require(:slug), user: Current.user)
        log.update!(plan: plan)
        render json: serialize_day(log.reload)
      end
    end
  end
end
