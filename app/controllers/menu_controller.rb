class MenuController < ApplicationController
  def show
    @daily_log = today_log
    @plan = @daily_log.plan
    @plans = Plan.ordered
    @meals = @plan.meals.includes(meal_items: :food)
    @completed_meal_ids = @daily_log.meal_completions.pluck(:meal_id)
    @can_copy_yesterday = @daily_log.has_uncopied_completions_from?(DailyLog.yesterday)
  end
end
