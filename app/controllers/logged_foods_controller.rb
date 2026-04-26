class LoggedFoodsController < ApplicationController
  def create
    food = Food.find(params[:food_id])
    quantity = params[:quantity_grams].presence&.to_d || food.serving_grams
    log = daily_log_from_params
    log.logged_foods.create!(food: food, quantity_grams: quantity, logged_at: Time.current)
    redirect_back fallback_location: fallback_for(log), notice: "#{food.name} logged"
  end

  def update
    entry = LoggedFood.find(params[:id])
    entry.update!(quantity_grams: params.require(:logged_food).require(:quantity_grams))
    redirect_back fallback_location: fallback_for(entry.daily_log), notice: "Quantity updated"
  end

  def destroy
    entry = LoggedFood.find(params[:id])
    log = entry.daily_log
    entry.destroy!
    redirect_back fallback_location: fallback_for(log), notice: "Removed"
  end

  private

  # Return to /days/:date for past-day edits, /today for today's.
  def fallback_for(log)
    log.date == Date.current ? root_path : day_path(log.date)
  end
end
