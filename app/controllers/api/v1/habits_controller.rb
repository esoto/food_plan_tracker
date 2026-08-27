module Api
  module V1
    class HabitsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        scope = params[:archived].to_s == "true" ? Current.user.habits.discarded.order(:label) : Current.user.habits.kept.ordered
        render json: { habits: scope.map { |t| serialize_habit(t) } }
      end

      def create
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
