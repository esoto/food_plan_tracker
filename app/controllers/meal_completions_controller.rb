class MealCompletionsController < ApplicationController
  before_action :set_daily_log, only: :create

  def create
    meal = Meal.find(params[:meal_id])
    @daily_log.meal_completions.find_or_create_by!(meal: meal) { |mc| mc.completed_at = Time.current }
    render partial: "menu/meal_card", locals: { meal: meal, completed: true, daily_log: @daily_log }
  end

  def destroy
    completion = MealCompletion.find(params[:id])
    meal = completion.meal
    daily_log = completion.daily_log
    completion.destroy!
    render partial: "menu/meal_card", locals: { meal: meal, completed: false, daily_log: daily_log }
  end

  private

  def set_daily_log
    @daily_log = daily_log_from_params
  end
end
