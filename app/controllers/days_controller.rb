class DaysController < ApplicationController
  def show
    date = Date.parse(params[:date])
    return redirect_to(root_path) if date == Date.current

    @daily_log = DailyLog.for(date, user: Current.user)
    @weight_goal = Current.user.goals.find_by(metric: :weight_kg)
    @prev_date = date - 1
    @next_date = date + 1 unless date >= Date.current

    if food_tracking?
      @plan = @daily_log.plan
      @plans = Current.user.plans.ordered
      @logged_foods = @daily_log.logged_foods.includes(:food)
    end
  end
end
