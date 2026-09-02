class LoggedFoodsController < ApplicationController
  include RequiresFoodTrackingHtml

  def create
    food = Food.find(params[:food_id])
    quantity = params[:quantity_grams].presence&.to_d || food.serving_grams
    log = daily_log_from_params
    log.logged_foods.create!(food: food, quantity_grams: quantity, logged_at: Time.current)
    redirect_to destination_for(log), notice: "#{food.name} logged"
  end

  # Inline auto-submit on blur can fire with a blank/zero value when the
  # user clears the field and tabs away. Catch the validation failure and
  # surface a flash instead of crashing back to a 500.
  def update
    entry = Current.user.logged_foods.find(params[:id])
    entry.update!(logged_food_params)
    redirect_to destination_for(entry.daily_log), notice: "Quantity updated"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to destination_for(entry.daily_log), alert: "Quantity #{e.record.errors[:quantity_grams].to_sentence.presence || 'is invalid'}"
  end

  def destroy
    entry = Current.user.logged_foods.find(params[:id])
    log = entry.daily_log
    entry.destroy!
    redirect_to destination_for(log), notice: "Removed"
  end

  private

  def logged_food_params
    params.require(:logged_food).permit(:quantity_grams)
  end

  # Authoritative landing page for the day in question — /today for
  # today, /days/:date for any past day. Using redirect_to (not
  # redirect_back) so the user's Referer doesn't bounce them back to
  # /exchanges after a "+ Log a food on this day" round-trip.
  def destination_for(log)
    log.date == Date.current ? root_path : day_path(log.date)
  end
end
