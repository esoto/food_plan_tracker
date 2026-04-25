module Api
  module V1
    class TodayController < Api::BaseController
      include Api::Concerns::DaySerializer

      def show
        render json: serialize_day(daily_log_for(nil))
      end
    end
  end
end
