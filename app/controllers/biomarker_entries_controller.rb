class BiomarkerEntriesController < ApplicationController
  def create
    goal = Goal.find(params[:biomarker_entry][:goal_id])
    entry = goal.biomarker_entries.new(
      recorded_on: params[:biomarker_entry][:recorded_on].presence || Date.current,
      value: params[:biomarker_entry][:value]
    )

    if entry.save
      if goal.weight_kg?
        target_log = daily_log_from_params
        target_log.update!(weight_kg: entry.value) if target_log.date == entry.recorded_on
      end
      redirect_back fallback_location: root_path, notice: "#{goal.display_name} logged"
    else
      redirect_back fallback_location: root_path, alert: entry.errors.full_messages.to_sentence
    end
  end
end
