class MealsController < ApplicationController
  def update
    meal = Meal.find(params[:id])
    if meal.update(meal_params)
      redirect_to settings_path, notice: "#{meal.name} updated.", status: :see_other
    else
      redirect_to settings_path, alert: meal.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  # The form posts scheduled_time as "HH:MM"; coerce to the UTC-sentinel Time
  # the model stores so display via .utc.strftime stays correct (see Architecture
  # doc — meals are stored as Time.utc(2000, 1, 1, h, m) to dodge SQLite tz drift).
  def meal_params
    raw = params.require(:meal).permit(:name, :scheduled_time, :target_kcal,
                                       :target_protein_g, :target_carbs_g, :target_fat_g)
    if raw[:scheduled_time].present? && raw[:scheduled_time].is_a?(String)
      h, m = raw[:scheduled_time].split(":").map(&:to_i)
      raw[:scheduled_time] = Time.utc(2000, 1, 1, h, m)
    end
    raw
  end
end
