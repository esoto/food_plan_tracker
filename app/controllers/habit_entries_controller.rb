class HabitEntriesController < ApplicationController
  def update
    habit = Current.user.habits.kept.find(params[:id])
    log = daily_log_from_params
    entry = log.habit_entries.find_or_initialize_by(habit: habit)
    entry.checked = params[:checked] == "1" || params[:checked] == "true"
    entry.save!
    redirect_back fallback_location: habits_path
  end
end
