class GoalsController < ApplicationController
  def update
    goal = Goal.find(params[:id])
    if goal.update(goal_params)
      redirect_to settings_path, notice: "#{goal.display_name} target updated."
    else
      redirect_to settings_path, alert: goal.errors.full_messages.to_sentence
    end
  end

  private

  def goal_params
    params.require(:goal).permit(:target_value)
  end
end
