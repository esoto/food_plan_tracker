class SupplementCompletionsController < ApplicationController
  before_action :set_daily_log, only: :create

  def create
    supplement = Current.user.supplements.kept.find(params[:supplement_id])
    completion = @daily_log.supplement_completions.find_or_create_by!(supplement: supplement) { |sc| sc.taken_at = Time.current }
    sync_related_habit(supplement, value: 1.0)
    if params[:source] == "reminder"
      flash[:undo] = { "path" => supplement_completion_path(completion), "label" => "Undo \"#{supplement.name}\"" }
    end
    redirect_back fallback_location: supplements_path
  end

  def destroy
    completion = SupplementCompletion.where(daily_log: Current.user.daily_logs).find(params[:id])
    supplement = completion.supplement
    daily_log  = completion.daily_log
    completion.destroy!
    sync_related_habit(supplement, value: 0.0, daily_log: daily_log)
    redirect_back fallback_location: supplements_path
  end

  private

  def set_daily_log
    @daily_log = daily_log_from_params
  end

  # Keep the "Took Fibrotina with dinner" habit in sync with the supplement
  # completion: marking supplement taken sets the habit's value to 1.0;
  # untoggling the supplement sets it back to 0.0. The habit can still be
  # toggled independently (e.g. you checked it manually and never marked the
  # supplement). Only syncs a *binary* Fibrotina habit — a rating/quantity/
  # duration habit that happens to match the label isn't pass/fail, so it's
  # left untouched.
  def sync_related_habit(supplement, value:, daily_log: @daily_log)
    return unless supplement.name.match?(/Fibrotina/i)

    habit = Current.user.habits.kept.find_by("label ILIKE ?", "%Fibrotina%")
    return unless habit&.binary?

    HabitEntry.set_value!(daily_log: daily_log, habit: habit, value: value)
  end
end
