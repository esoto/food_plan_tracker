module Api
  module V1
    class MealsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        plan = if params[:plan].present?
          Plan.find_by!(slug: params[:plan])
        else
          daily_log_for(params[:date]).plan
        end

        meals = plan.meals.includes(meal_items: :food).ordered
        render json: { plan: serialize_plan(plan), meals: meals.map { |m| serialize_meal(m) } }
      end
    end
  end
end
