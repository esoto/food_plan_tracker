class ProgressController < ApplicationController
  def show
    @weight_goal = Goal.find_by(metric: Goal.metrics[:weight_kg])
    @weight_entries = @weight_goal&.biomarker_entries&.where("recorded_on >= ?", 90.days.ago)&.chronological || []
    @goals = Goal.all.includes(:biomarker_entries)
    @recent_logs = DailyLog.where(date: 13.days.ago.to_date..Date.current).order(:date)
  end
end
