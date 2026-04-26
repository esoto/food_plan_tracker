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

  # Copies yesterday's meal completions onto today. Only operates when both
  # days share a plan (different plans have different meal_ids and copying
  # across them would mean nothing). find_or_create_by makes the operation
  # idempotent — partial completes today are preserved, missing ones added.
  def copy_yesterday
    today = today_log
    yesterday = DailyLog.find_by(date: Date.current - 1)

    if yesterday.nil? || yesterday.plan_id != today.plan_id
      redirect_to(menu_path, alert: "Yesterday's plan doesn't match today — nothing to copy.") and return
    end

    yesterday.meal_completions.each do |mc|
      today.meal_completions.find_or_create_by!(meal_id: mc.meal_id) { |new_mc| new_mc.completed_at = Time.current }
    end

    redirect_to menu_path, status: :see_other,
                notice: "Copied #{yesterday.meal_completions.size} meals from yesterday."
  end

  private

  def set_daily_log
    @daily_log = daily_log_from_params
  end
end
