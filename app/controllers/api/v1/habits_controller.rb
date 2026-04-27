module Api
  module V1
    class HabitsController < Api::BaseController
      include Api::Concerns::DaySerializer

      def index
        scope = params[:archived].to_s == "true" ? ChecklistTemplate.discarded.order(:label) : ChecklistTemplate.kept.ordered
        render json: { habits: scope.map { |t| serialize_habit(t) } }
      end

      def create
        template = ChecklistTemplate.new(habit_params)
        template.position = ChecklistTemplate.next_position
        template.save!
        render json: { habit: serialize_habit(template) }, status: :created
      end

      def update
        template = ChecklistTemplate.find(params[:id])
        template.update!(habit_params)
        render json: { habit: serialize_habit(template) }
      end

      def destroy
        template = ChecklistTemplate.find(params[:id])
        template.discard!
        render json: { habit: serialize_habit(template) }
      end

      def restore
        template = ChecklistTemplate.find(params[:id])
        template.restore_at_end!
        render json: { habit: serialize_habit(template) }
      end

      private

      def habit_params
        params.require(:habit).permit(:label, :description, :icon, :position)
      end
    end
  end
end
