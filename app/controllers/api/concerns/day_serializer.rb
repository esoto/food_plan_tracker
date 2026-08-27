module Api
  module Concerns
    module DaySerializer
      extend ActiveSupport::Concern

      private

      def serialize_day(log)
        plan = log.plan
        meals = plan.meals.includes(meal_items: :food)

        {
          date: log.date.iso8601,
          plan: serialize_plan(plan),
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

      def serialize_plan(plan)
        {
          id: plan.id,
          slug: plan.slug,
          name: plan.name,
          target_kcal:      plan.target_kcal,
          target_protein_g: plan.target_protein_g.to_f,
          target_carbs_g:   plan.target_carbs_g.to_f,
          target_fat_g:     plan.target_fat_g.to_f
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
          protein_g:      lf.protein_g.to_f,
          carbs_g:        lf.carbs_g.to_f,
          fat_g:          lf.fat_g.to_f,
          logged_at:      lf.logged_at.iso8601
        }
      end

      def serialize_meal(meal)
        items = meal.meal_items.map do |mi|
          {
            food_id:        mi.food_id,
            food_name:      mi.food.name,
            category:       mi.food.category,
            quantity_grams: mi.quantity_grams.to_f,
            kcal:           mi.kcal,
            protein_g:      mi.protein_g.to_f,
            carbs_g:        mi.carbs_g.to_f,
            fat_g:          mi.fat_g.to_f
          }
        end

        {
          id:               meal.id,
          name:             meal.name,
          position:         meal.position,
          time_of_day:      meal.time_of_day,
          target_kcal:      meal.target_kcal,
          target_protein_g: meal.target_protein_g.to_f,
          target_carbs_g:   meal.target_carbs_g.to_f,
          target_fat_g:     meal.target_fat_g.to_f,
          # Totals are summed from the already-rounded per-item values (each
          # MealItem#protein_g/carbs_g/fat_g rounds to 1 decimal; #kcal rounds
          # to integer). The final round(1) catches floating-point drift on
          # the macro sums. Note: this is meal-plan math (target_food × ratio),
          # not the same path as DailyLog#consumed_*, which sums per-day
          # LoggedFood records — the two endpoints answer different questions.
          totals: {
            kcal:      items.sum { |i| i[:kcal] },
            protein_g: items.sum { |i| i[:protein_g] }.round(1),
            carbs_g:   items.sum { |i| i[:carbs_g] }.round(1),
            fat_g:     items.sum { |i| i[:fat_g] }.round(1)
          },
          items: items
        }
      end

      def serialize_food(food)
        {
          id:            food.id,
          name:          food.name,
          category:      food.category,
          serving_grams: food.serving_grams.to_f,
          kcal:          food.kcal,
          protein_g:     food.protein_g.to_f,
          carbs_g:       food.carbs_g.to_f,
          fat_g:         food.fat_g.to_f
        }
      end

      def serialize_meal_item(item)
        {
          id:             item.id,
          food_id:        item.food_id,
          food_name:      item.food.name,
          category:       item.food.category,
          quantity_grams: item.quantity_grams.to_f,
          kcal:           item.kcal,
          protein_g:      item.protein_g.to_f,
          carbs_g:        item.carbs_g.to_f,
          fat_g:          item.fat_g.to_f
        }
      end

      def serialize_supplement(supplement)
        {
          id:                supplement.id,
          name:              supplement.name,
          dose:              supplement.dose,
          critical:          supplement.critical,
          notes:             supplement.notes,
          contraindications: supplement.contraindications,
          time_slots:        supplement.supplement_schedules.map(&:time_slot).uniq,
          discarded_at:      supplement.discarded_at&.iso8601
        }
      end

      def serialize_habit(template)
        {
          id:           template.id,
          label:        template.label,
          description:  template.description,
          icon:         template.icon,
          position:     template.position,
          kind:         template.kind,
          unit:         template.unit,
          target_value: template.target_value,
          rating_scale: template.rating_scale,
          discarded_at: template.discarded_at&.iso8601
        }
      end

      def serialize_goal(goal)
        {
          id:             goal.id,
          metric:         goal.metric,
          display_name:   goal.display_name,
          unit:           goal.unit,
          direction:      goal.direction,
          starting_value: goal.starting_value.to_f,
          current_value:  goal.current_value.to_f,
          target_value:   goal.target_value.to_f,
          progress_pct:   goal.progress_pct
        }
      end
    end
  end
end
