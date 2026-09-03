module Api
  module V1
    class HabitsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        scope = params[:archived].to_s == "true" ? Current.user.habits.discarded.order(:label) : Current.user.habits.kept.ordered
        habits = scope.to_a

        if params[:date].present?
          log = daily_log_for(params[:date])
          entries_by_habit = HabitEntry.includes(:habit, :daily_log).where(daily_log: log, habit_id: habits.map(&:id)).index_by(&:habit_id)
          payload = habits.map { |h| serialize_habit(h).merge(entry: entries_by_habit[h.id]&.then { |e| serialize_habit_entry(e) }) }
        else
          payload = habits.map { |h| serialize_habit(h) }
        end

        render json: { habits: payload }
      end

      def create
        # kind is an enum — EnumType casts a blank string to nil, which would
        # otherwise sail past validation and hit the kind NOT NULL constraint
        # as a 500. Raise ArgumentError up front so it flows through the same
        # rescue_from path (-> 422) as an unrecognized kind value.
        if habit_params.key?(:kind) && !Habit.valid_kind?(habit_params[:kind])
          raise ArgumentError, "#{habit_params[:kind].inspect} is not a valid kind"
        end

        habit = Current.user.habits.new(habit_params)
        habit.position = Habit.next_position(user: Current.user)
        habit.save!
        render json: { habit: serialize_habit(habit) }, status: :created
      end

      def update
        habit = Current.user.habits.find(params[:id])
        habit.update!(habit_params)
        render json: { habit: serialize_habit(habit) }
      end

      def destroy
        habit = Current.user.habits.find(params[:id])
        habit.discard!
        render json: { habit: serialize_habit(habit) }
      end

      def restore
        habit = Current.user.habits.find(params[:id])
        habit.restore_at_end!
        render json: { habit: serialize_habit(habit) }
      end

      private

      # kind is a lookup key, not just a value — it's only settable at creation.
      # Changing it under existing entries corrupts semantics (same philosophy
      # as the MCP name rule and Settings::HabitsController), so update permits
      # everything except :kind and silently ignores any kind param sent.
      def habit_params
        permitted = %i[label description icon position unit target_value rating_scale]
        permitted << :kind if action_name == "create"
        params.require(:habit).permit(*permitted)
      end
    end
  end
end
