module Api
  module V1
    class GoalsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        render json: { goals: Goal.all.map { |g| serialize_goal(g) } }
      end
    end
  end
end
