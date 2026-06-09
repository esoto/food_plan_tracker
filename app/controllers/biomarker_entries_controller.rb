class BiomarkerEntriesController < ApplicationController
  def new
    @goals = Current.user.goals
    @recorded_on = (params[:date].presence && Date.parse(params[:date])) || Date.current
  end

  def create
    goal = Current.user.goals.find(params[:biomarker_entry][:goal_id])
    entry = goal.biomarker_entries.new(
      recorded_on: params[:biomarker_entry][:recorded_on].presence || Date.current,
      value: params[:biomarker_entry][:value]
    )

    if entry.save
      sync_weight_log(goal, entry)
      redirect_back fallback_location: root_path, notice: "#{goal.display_name} logged"
    else
      redirect_back fallback_location: root_path, alert: entry.errors.full_messages.to_sentence
    end
  end

  # Bulk-create entries from the /biomarker_entries/new form. Skips blank values
  # so the user only fills in what came back from a panel.
  def bulk
    recorded_on = params[:recorded_on].presence ? Date.parse(params[:recorded_on]) : Date.current
    submitted   = (params[:entries] || {}).select { |_, v| v.to_s.strip.present? }

    if submitted.empty?
      redirect_to new_biomarker_entry_path, alert: "Enter at least one value." and return
    end

    created = []
    Current.user.goals.where(id: submitted.keys).find_each do |goal|
      value = submitted[goal.id.to_s]
      entry = goal.biomarker_entries.create!(value: value, recorded_on: recorded_on)
      sync_weight_log(goal, entry)
      created << goal.display_name
    end

    redirect_to progress_path, status: :see_other,
                notice: "Logged #{created.size} #{'reading'.pluralize(created.size)}: #{created.join(', ')}."
  end

  private

  def sync_weight_log(goal, entry)
    return unless goal.weight_kg?
    target_log = daily_log_from_params
    target_log.update!(weight_kg: entry.value) if target_log.date == entry.recorded_on
  end
end
