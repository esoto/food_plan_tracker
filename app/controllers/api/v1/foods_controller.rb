module Api
  module V1
    class FoodsController < Api::BaseController
      include Api::Concerns::DaySerializer
      include Api::Concerns::RequiresFoodTracking

      def index
        scope = Food.alphabetical
        if params[:q].present?
          scope = scope.where("LOWER(name) LIKE ?", "%#{params[:q].to_s.downcase}%")
        end
        render json: { foods: scope.limit(20).map { |f| serialize_food(f) } }
      end

      def create
        food = Food.create!(food_params)
        render json: { food: serialize_food(food) }, status: :created
      end

      private

      def food_params
        params.require(:food).permit(:name, :category, :serving_grams, :kcal,
                                     :protein_g, :carbs_g, :fat_g, :notes)
      end
    end
  end
end
