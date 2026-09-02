module Api
  module V1
    class MealsController < Api::BaseController
      include Api::Concerns::DaySerializer
      include Api::Concerns::RequiresFoodTracking

      def index
        plan = if params[:plan].present?
          Plan.find_by_slug!(params[:plan], user: Current.user)
        else
          daily_log_for(params[:date]).plan
        end

        meals = plan.meals.includes(meal_items: :food).ordered
        render json: { plan: serialize_plan(plan), meals: meals.map { |m| serialize_meal(m) } }
      end

      def update
        meal = Current.user.meals.find(params[:id])
        meal.update!(meal_params)
        render json: { meal: serialize_meal(meal.reload) }
      rescue Meal::InvalidScheduledTime => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      # scheduled_time arrives as "HH:MM"; coercion to the UTC-sentinel Time
      # is owned by Meal#scheduled_time= (model-level). Bad input raises
      # Meal::InvalidScheduledTime, caught above as 422.
      def meal_params
        params.require(:meal).permit(:name, :scheduled_time, :target_kcal,
                                     :target_protein_g, :target_carbs_g, :target_fat_g)
      end
    end
  end
end
