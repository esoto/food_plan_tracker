module Api
  module V1
    class WeeklySummaryController < Api::BaseController
      def show
        summary = WeeklySummary.rolling_7_days(user: Current.user)

        render json: {
          window_days: 7,
          start_date: summary.start_date.iso8601,
          end_date:   summary.end_date.iso8601,
          adherence_pct:             summary.adherence_pct,
          weight_delta_kg:           summary.weight_delta_kg,
          meal_completion_pct:       summary.meal_completion_pct,
          supplement_completion_pct: summary.supplement_completion_pct
        }
      end
    end
  end
end
