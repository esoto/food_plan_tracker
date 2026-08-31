class HabitEntriesController < ApplicationController
  def update
    habit = Current.user.habits.kept.find(params[:id])
    log = daily_log_from_params

    if params[:delta].present?
      HabitEntry.increment_value!(daily_log: log, habit: habit, delta: params[:delta].to_f)
    else
      HabitEntry.set_value!(daily_log: log, habit: habit, value: params[:value].to_f)
    end
    redirect_back fallback_location: habits_path
  rescue HabitEntry::InvalidValue => e
    redirect_back fallback_location: habits_path, alert: e.message
  end
end
