module Api
  module V1
    class LoggedFoodsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def create
        food = Food.find(params[:food_id])
        log = daily_log_for(params[:date])
        quantity = params[:quantity_grams].presence&.to_d || food.serving_grams
        log.logged_foods.create!(food: food, quantity_grams: quantity, logged_at: Time.current)
        render json: { ok: true, day: serialize_day(log.reload) }, status: :created
      end

      def destroy
        entry = Current.user.logged_foods.find(params[:id])
        log = entry.daily_log
        entry.destroy!
        render json: { ok: true, day: serialize_day(log.reload) }
      end
    end
  end
end
