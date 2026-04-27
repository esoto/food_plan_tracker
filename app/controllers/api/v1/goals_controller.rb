module Api
  module V1
    class GoalsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        render json: { goals: Goal.all.map { |g| serialize_goal(g) } }
      end

      def update
        goal = Goal.find(params[:id])
        goal.update!(goal_params)
        render json: { goal: serialize_goal(goal) }
      end

      private

      def goal_params
        params.require(:goal).permit(:target_value)
      end
    end
  end
end
