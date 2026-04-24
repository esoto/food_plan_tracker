class SupplementCompletionsController < ApplicationController
  before_action :set_daily_log, only: :create

  def create
    supplement = Supplement.find(params[:supplement_id])
    @daily_log.supplement_completions.find_or_create_by!(supplement: supplement) { |sc| sc.taken_at = Time.current }
    auto_check_related_habit(supplement)
    redirect_back fallback_location: supplements_path
  end

  def destroy
    completion = SupplementCompletion.find(params[:id])
    completion.destroy!
    redirect_back fallback_location: supplements_path
  end

  private

  def set_daily_log
    @daily_log = today_log
  end

  # Marking Fibrotina taken also checks the "Took Fibrotina with dinner" habit
  # so the two views stay in sync.
  def auto_check_related_habit(supplement)
    return unless supplement.name.match?(/Fibrotina/i)

    template = ChecklistTemplate.find_by("label LIKE ?", "%Fibrotina%")
    return unless template

    completion = @daily_log.checklist_completions.find_or_initialize_by(checklist_template: template)
    completion.checked = true
    completion.save!
  end
end
