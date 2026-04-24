class MenuController < ApplicationController
  def show
    @daily_log = today_log
    @plan = @daily_log.plan
    @meals = @plan.meals.includes(meal_items: :food)
    @completed_meal_ids = @daily_log.meal_completions.pluck(:meal_id)
  end
end
