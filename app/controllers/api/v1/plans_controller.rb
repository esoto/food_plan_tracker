module Api
  module V1
    class PlansController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        render json: { plans: Plan.ordered.map { |p| serialize_plan(p) } }
      end

      def update
        plan = Plan.find(params[:id])
        plan.update!(plan_params)
        render json: { plan: serialize_plan(plan) }
      end

      private

      def plan_params
        params.require(:plan).permit(:target_kcal, :target_protein_g, :target_carbs_g, :target_fat_g)
      end
    end
  end
end
