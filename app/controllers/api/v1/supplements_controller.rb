module Api
  module V1
    class SupplementsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        scope = params[:archived].to_s == "true" ? Current.user.supplements.discarded : Current.user.supplements.kept
        scope = scope.includes(:supplement_schedules).order(critical: :desc, name: :asc)
        render json: { supplements: scope.map { |s| serialize_supplement(s) } }
      end

      def create
        supplement = Current.user.supplements.create!(supplement_params)
        supplement.sync_time_slots!(params[:time_slots]) if params.key?(:time_slots)
        render json: { supplement: serialize_supplement(supplement.reload) }, status: :created
      end

      def update
        supplement = Current.user.supplements.find(params[:id])
        supplement.update!(supplement_params)
        supplement.sync_time_slots!(params[:time_slots]) if params.key?(:time_slots)
        render json: { supplement: serialize_supplement(supplement.reload) }
      end

      def destroy
        supplement = Current.user.supplements.find(params[:id])
        supplement.discard!
        render json: { supplement: serialize_supplement(supplement) }
      end

      def restore
        supplement = Current.user.supplements.find(params[:id])
        supplement.restore!
        render json: { supplement: serialize_supplement(supplement) }
      end

      private

      def supplement_params
        params.require(:supplement).permit(:name, :dose, :critical, :notes, :contraindications)
      end
    end
  end
end
