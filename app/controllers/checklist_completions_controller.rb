class ChecklistCompletionsController < ApplicationController
  def update
    template = Current.user.checklist_templates.kept.find(params[:id])
    log = daily_log_from_params
    completion = log.checklist_completions.find_or_initialize_by(checklist_template: template)
    completion.checked = params[:checked] == "1" || params[:checked] == "true"
    completion.save!
    redirect_back fallback_location: checklist_path
  end
end
