module Api
  module V1
    class TodayController < Api::BaseController
      def show
        log = daily_log_for(nil)
        render json: serialize_day(log)
      end

      private

      def serialize_day(log)
        plan = log.plan
        meals = plan.meals.includes(meal_items: :food)

        {
          date: log.date.iso8601,
          plan: { id: plan.id, slug: plan.slug, name: plan.name },
          targets: {
            kcal:      plan.target_kcal,
            protein_g: plan.target_protein_g.to_f,
            carbs_g:   plan.target_carbs_g.to_f,
            fat_g:     plan.target_fat_g.to_f
          },
          consumed: {
            kcal:      log.consumed_kcal,
            protein_g: log.consumed_protein_g,
            carbs_g:   log.consumed_carbs_g,
            fat_g:     log.consumed_fat_g
          },
          weight_kg: log.weight_kg&.to_f,
          completed_meal_ids: log.meal_completions.pluck(:meal_id),
          now_meal: serialize_now_meal(meals.detect(&:now?)),
          logged_foods: log.logged_foods.includes(:food).map { |lf| serialize_logged_food(lf) }
        }
      end

      def serialize_now_meal(meal)
        return nil unless meal
        { id: meal.id, name: meal.name, time_of_day: meal.time_of_day }
      end

      def serialize_logged_food(lf)
        {
          id:             lf.id,
          food_id:        lf.food_id,
          food_name:      lf.food.name,
          quantity_grams: lf.quantity_grams.to_f,
          kcal:           lf.kcal,
          protein_g:      lf.protein_g,
          carbs_g:        lf.carbs_g,
          fat_g:          lf.fat_g,
          logged_at:      lf.logged_at.iso8601
        }
      end
    end
  end
end
