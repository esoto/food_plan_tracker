module Api
  module V1
    class WeightController < Api::BaseController
      include Api::Concerns::DaySerializer

      def create
        goal = Goal.find_by_metric!(Goal.metrics[:weight_kg], user: Current.user)
        date = params[:date].present? ? Date.parse(params[:date].to_s) : Date.current
        value = params.require(:value)

        entry = goal.biomarker_entries.create!(value: value, recorded_on: date)
        log = DailyLog.for(Current.user, date)
        log.update!(weight_kg: entry.value) if log.date == entry.recorded_on

        render json: {
          ok: true,
          entry: { id: entry.id, value: entry.value.to_f, recorded_on: entry.recorded_on.iso8601 },
          day: serialize_day(log.reload)
        }, status: :created
      end
    end
  end
end
