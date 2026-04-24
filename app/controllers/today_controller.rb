class TodayController < ApplicationController
  def show
    @plans = Plan.ordered
    @daily_log = today_log
    @plan = @daily_log.plan
    @meals = @plan.meals.includes(meal_items: :food)
    @completed_meal_ids = @daily_log.meal_completions.pluck(:meal_id)
    @goals = Goal.all
    @recent_weights = BiomarkerEntry
      .joins(:goal)
      .where(goals: { metric: Goal.metrics[:weight_kg] })
      .order(recorded_on: :desc)
      .limit(30)
  end
end
