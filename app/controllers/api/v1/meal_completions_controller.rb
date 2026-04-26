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

      def copy_yesterday
        target_date = params[:date].present? ? Date.parse(params[:date].to_s) : Date.current
        yesterday = DailyLog.find_by(date: target_date - 1)

        if yesterday.nil?
          return render json: { error: "no_yesterday_log" }, status: :unprocessable_entity
        end

        existing_today = DailyLog.find_by(date: target_date)
        if existing_today && !existing_today.can_copy_from?(yesterday)
          return render json: { error: "plan_mismatch", today_plan: existing_today.plan.slug, yesterday_plan: yesterday.plan.slug }, status: :unprocessable_entity
        end

        today = existing_today || DailyLog.for(target_date, default_plan: yesterday.plan)
        copied = today.copy_completions_from(yesterday)
        render json: { ok: true, copied: copied, day: serialize_day(today.reload) }
      end
    end
  end
end
