class SupplementCompletionsController < ApplicationController
  before_action :set_daily_log, only: :create

  def create
    supplement = Supplement.find(params[:supplement_id])
    @daily_log.supplement_completions.find_or_create_by!(supplement: supplement) { |sc| sc.taken_at = Time.current }
    sync_related_habit(supplement, checked: true)
    redirect_back fallback_location: supplements_path
  end

  def destroy
    completion = SupplementCompletion.find(params[:id])
    supplement = completion.supplement
    daily_log  = completion.daily_log
    completion.destroy!
    sync_related_habit(supplement, checked: false, daily_log: daily_log)
    redirect_back fallback_location: supplements_path
  end

  private

  def set_daily_log
    @daily_log = daily_log_from_params
  end

  # Keep the "Took Fibrotina with dinner" habit in sync with the supplement
  # completion: marking supplement taken checks the habit; untoggling the
  # supplement unchecks it. The habit can still be toggled independently
  # (e.g. you checked it manually and never marked the supplement).
  def sync_related_habit(supplement, checked:, daily_log: @daily_log)
    return unless supplement.name.match?(/Fibrotina/i)

    template = ChecklistTemplate.find_by("label LIKE ?", "%Fibrotina%")
    return unless template

    completion = daily_log.checklist_completions.find_or_initialize_by(checklist_template: template)
    completion.checked = checked
    completion.save!
  end
end
