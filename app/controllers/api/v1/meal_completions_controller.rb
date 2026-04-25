module Api
  module V1
    class MealCompletionsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def create
        log = daily_log_for(params[:date])
        meal = Meal.find(params[:meal_id])
        log.meal_completions.find_or_create_by!(meal: meal) { |mc| mc.completed_at = Time.current }
        render json: { ok: true, day: serialize_day(log.reload) }, status: :created
      end

      def destroy
        log = daily_log_for(params[:date])
        completion = log.meal_completions.find_by!(meal_id: params[:meal_id])
        completion.destroy!
        render json: { ok: true, day: serialize_day(log.reload) }
      end
    end
  end
end
