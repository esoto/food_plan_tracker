class ProgressController < ApplicationController
  def show
    @weight_goal = Goal.for_user(Current.user).find_by(metric: Goal.metrics[:weight_kg])
    @weight_entries = @weight_goal&.biomarker_entries&.where("recorded_on >= ?", 90.days.ago)&.chronological || []
    @goals = Goal.for_user(Current.user).includes(:biomarker_entries)
    @recent_logs = DailyLog.for_user(Current.user).where(date: 13.days.ago.to_date..Date.current).order(:date)
    @weekly_summary = WeeklySummary.rolling_7_days(user: Current.user)
  end
end
