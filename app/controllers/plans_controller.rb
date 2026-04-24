class PlansController < ApplicationController
  def update
    plan = Plan.find(params[:id])
    if plan.update(plan_params)
      redirect_to settings_path, notice: "#{plan.name} targets updated."
    else
      redirect_to settings_path, alert: plan.errors.full_messages.to_sentence
    end
  end

  private

  def plan_params
    params.require(:plan).permit(:target_kcal, :target_protein_g, :target_carbs_g, :target_fat_g)
  end
end
