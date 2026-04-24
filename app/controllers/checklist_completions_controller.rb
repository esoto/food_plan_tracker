class ChecklistCompletionsController < ApplicationController
  def update
    template = ChecklistTemplate.find(params[:id])
    log = today_log
    completion = log.checklist_completions.find_or_initialize_by(checklist_template: template)
    completion.checked = params[:checked] == "1" || params[:checked] == "true"
    completion.save!
    redirect_back fallback_location: checklist_path
  end
end
