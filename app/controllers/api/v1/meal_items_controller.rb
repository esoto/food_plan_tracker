module Api
  module V1
    class MealItemsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        meal = Meal.find(params[:meal_id])
        render json: { meal_items: meal.meal_items.includes(:food).map { |i| serialize_meal_item(i) } }
      end

      def create
        meal = Meal.find(params[:meal_id])
        item = meal.meal_items.create!(meal_item_params)
        render json: { meal_item: serialize_meal_item(item) }, status: :created
      end

      def update
        item = MealItem.find(params[:id])
        item.update!(meal_item_params)
        render json: { meal_item: serialize_meal_item(item) }
      end

      def destroy
        item = MealItem.find(params[:id])
        id = item.id
        item.destroy!
        render json: { removed: true, id: id }
      end

      private

      # food_id is permitted only on create; PATCH ignores it (use a fresh
      # remove + add to swap the underlying food rather than reassigning a
      # row, which would invalidate display_order intent).
      def meal_item_params
        if action_name == "create"
          params.require(:meal_item).permit(:food_id, :quantity_grams, :display_order)
        else
          params.require(:meal_item).permit(:quantity_grams, :display_order)
        end
      end
    end
  end
end
