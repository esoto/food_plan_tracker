class DaysController < ApplicationController
  def show
    date = Date.parse(params[:date])
    return redirect_to(root_path) if date == Date.current

    @daily_log = DailyLog.for(Current.user, date)
    @plan = @daily_log.plan
    @plans = Plan.ordered
    @logged_foods = @daily_log.logged_foods.includes(:food)
    @prev_date = date - 1
    @next_date = date + 1 unless date >= Date.current
  end
end
