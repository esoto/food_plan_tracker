class PlansController < ApplicationController
  def update
    plan = Current.user.plans.find(params[:id])
    if plan.update(plan_params)
      redirect_to settings_path, notice: "#{plan.name} targets updated.", status: :see_other
    else
      redirect_to settings_path, alert: plan.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def plan_params
    params.require(:plan).permit(:target_kcal, :target_protein_g, :target_carbs_g, :target_fat_g)
  end
end
