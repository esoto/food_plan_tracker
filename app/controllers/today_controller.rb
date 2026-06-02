class TodayController < ApplicationController
  def show
    @plans = Current.user.plans.ordered
    @daily_log = today_log
    @plan = @daily_log.plan
    @meals = @plan.meals.includes(meal_items: :food)
    @completed_meal_ids = @daily_log.meal_completions.pluck(:meal_id)
    @now_meal = @meals.detect(&:now?)
    @logged_foods = @daily_log.logged_foods.includes(:food)
    @goals = Goal.for_user(Current.user).with_measurements.includes(:biomarker_entries).to_a
    @untracked_goal_count = Current.user.goals.count - @goals.size
    @recent_weights = BiomarkerEntry
      .for_user(Current.user)
      .joins(:goal)
      .where(goals: { metric: Goal.metrics[:weight_kg] })
      .order(recorded_on: :desc)
      .limit(30)
  end
end
