class MenuController < ApplicationController
  def show
    @daily_log = today_log
    @plan = @daily_log.plan
    @plans = Plan.ordered
    @meals = @plan.meals.includes(meal_items: :food)
    @completed_meal_ids = @daily_log.meal_completions.pluck(:meal_id)

    yesterday = DailyLog.find_by(date: Date.current - 1)
    yesterday_count = yesterday&.meal_completions&.size.to_i
    @can_copy_yesterday = yesterday.present? &&
                          yesterday.plan_id == @daily_log.plan_id &&
                          yesterday_count.positive? &&
                          yesterday_count > @completed_meal_ids.size
  end
end
