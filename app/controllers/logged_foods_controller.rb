class LoggedFoodsController < ApplicationController
  def create
    food = Food.find(params[:food_id])
    quantity = params[:quantity_grams].presence&.to_d || food.serving_grams
    today_log.logged_foods.create!(food: food, quantity_grams: quantity, logged_at: Time.current)
    redirect_back fallback_location: exchanges_path, notice: "#{food.name} logged"
  end

  def destroy
    entry = LoggedFood.find(params[:id])
    entry.destroy!
    redirect_back fallback_location: root_path, notice: "Removed"
  end
end
