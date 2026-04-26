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
  # across them would mean nothing). Idempotent — partial completes today
  # are preserved.
  def copy_yesterday
    today = today_log
    yesterday = DailyLog.yesterday

    if yesterday.nil?
      return redirect_to(menu_path, status: :see_other, alert: "No log from yesterday yet — nothing to copy.")
    end

    if yesterday.plan_id != today.plan_id
      return redirect_to(menu_path, status: :see_other, alert: "Yesterday's plan doesn't match today — nothing to copy.")
    end

    copied = today.copy_completions_from(yesterday)
    redirect_to menu_path, status: :see_other,
                notice: "Copied #{copied} #{'meal'.pluralize(copied)} from yesterday."
  end

  private

  def set_daily_log
    @daily_log = daily_log_from_params
  end
end
