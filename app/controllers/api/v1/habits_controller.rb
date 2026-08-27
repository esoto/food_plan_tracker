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

      def habit_params
        params.require(:habit).permit(:label, :description, :icon, :position)
      end
    end
  end
end
