module Api
  module V1
    class FoodsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        scope = Food.alphabetical
        if params[:q].present?
          scope = scope.where("LOWER(name) LIKE ?", "%#{params[:q].to_s.downcase}%")
        end
        render json: { foods: scope.limit(20).map { |f| serialize_food(f) } }
      end
    end
  end
end
