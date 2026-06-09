class MealsController < ApplicationController
  def update
    meal = Current.user.meals.find(params[:id])
    if meal.update(meal_params)
      redirect_to settings_path, notice: "#{meal.name} updated.", status: :see_other
    else
      redirect_to settings_path, alert: meal.errors.full_messages.to_sentence, status: :see_other
    end
  rescue Meal::InvalidScheduledTime => e
    redirect_to settings_path, alert: e.message, status: :see_other
  end

  private

  # scheduled_time arrives as "HH:MM"; coercion to the UTC-sentinel Time is
  # owned by Meal#scheduled_time= (model-level), so this just whitelists
  # params. Bad input raises Meal::InvalidScheduledTime, caught above.
  def meal_params
    params.require(:meal).permit(:name, :scheduled_time, :target_kcal,
                                 :target_protein_g, :target_carbs_g, :target_fat_g)
  end
end
