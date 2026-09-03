module Api
  module V1
    class HabitEntriesController < Api::BaseController
      include Api::Concerns::DaySerializer

      def create
        habit = Current.user.habits.kept.find(params[:habit_id])
        attrs = entry_params
        log = DailyLog.for(Current.user, attrs[:date])

        if attrs[:value].present?
          HabitEntry.set_value!(
            daily_log: log,
            habit:     habit,
            value:     attrs[:value].to_f
          )
        elsif attrs[:delta].present?
          HabitEntry.increment_value!(
            daily_log: log,
            habit:     habit,
            delta:     attrs[:delta].to_f
          )
        else
          raise ActionController::ParameterMissing, :value
        end

        entry = HabitEntry.find_by!(daily_log: log, habit: habit)
        render json: { habit: serialize_habit(habit), entry: serialize_habit_entry(entry) },
               status: :created
      end

      private

      def entry_params
        params.require(:entry).permit(:date, :value, :delta)
      end
    end
  end
end