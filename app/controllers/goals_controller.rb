class GoalsController < ApplicationController
  # First-run weight-goal creation from the dashboard weight card. The card
  # is the only UI that creates goals (settings only edits targets), so this
  # action is deliberately weight-specific: it seeds the goal AND logs the
  # current weight as the first entry, completing setup in one submit.
  def create
    if Current.user.goals.weight_kg.exists?
      redirect_to root_path, status: :see_other and return
    end

    goal = Current.user.goals.create!(
      metric: :weight_kg, display_name: "Weight", unit: "kg", direction: :down,
      starting_value: create_params[:starting_value], target_value: create_params[:target_value]
    )
    entry = goal.biomarker_entries.create!(recorded_on: Date.current, value: goal.starting_value)
    today_log.update!(weight_kg: entry.value)

    redirect_to root_path, notice: "Weight goal set — first entry logged.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to root_path, alert: e.record.errors.full_messages.to_sentence, status: :see_other
  end

  def update
    goal = Current.user.goals.find(params[:id])
    if goal.update(goal_params)
      redirect_to settings_path, notice: "#{goal.display_name} target updated.", status: :see_other
    else
      redirect_to settings_path, alert: goal.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def goal_params
    params.require(:goal).permit(:target_value)
  end

  def create_params
    params.require(:goal).permit(:starting_value, :target_value)
  end
end
