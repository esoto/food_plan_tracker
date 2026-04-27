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

      def update
        meal = Meal.find(params[:id])
        attrs = meal_params
        meal.update!(attrs)
        render json: { meal: serialize_meal(meal.reload) }
      rescue InvalidScheduledTime => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      class InvalidScheduledTime < StandardError; end

      # Mirrors the HTML controller: scheduled_time arrives as "HH:MM" and is
      # coerced to the UTC-sentinel Time the model stores. Bad input raises
      # InvalidScheduledTime which the action catches and returns as 422.
      def meal_params
        raw = params.require(:meal).permit(:name, :scheduled_time, :target_kcal,
                                            :target_protein_g, :target_carbs_g, :target_fat_g)
        if raw[:scheduled_time].present? && raw[:scheduled_time].is_a?(String)
          unless raw[:scheduled_time].match?(/\A\d{1,2}:\d{2}\z/)
            raise InvalidScheduledTime, "scheduled_time must be HH:MM"
          end

          h, m = raw[:scheduled_time].split(":").map(&:to_i)
          unless (0..23).cover?(h) && (0..59).cover?(m)
            raise InvalidScheduledTime, "scheduled_time must be HH:MM (0-23 hour, 0-59 minute)"
          end

          raw[:scheduled_time] = Time.utc(2000, 1, 1, h, m)
        end
        raw
      end
    end
  end
end
