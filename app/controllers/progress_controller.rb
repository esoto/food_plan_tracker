class ProgressController < ApplicationController
  def show
    @weight_goal = Goal.for_user(Current.user).find_by(metric: Goal.metrics[:weight_kg])
    @weight_entries = @weight_goal&.biomarker_entries&.where("recorded_on >= ?", 90.days.ago)&.chronological || []
    @goals = Goal.for_user(Current.user).includes(:biomarker_entries)
    @recent_logs = DailyLog.for_user(Current.user).where(date: 13.days.ago.to_date..Date.current).order(:date)
    @weekly_summary = WeeklySummary.rolling_7_days(user: Current.user)
    @rating_trends = build_rating_trends
  end

  private

  # Ratings are walled out of adherence/streak/heatmap by design — trends
  # (7-day avg, delta vs the prior 7 days, and a 14-day sparkline) are their
  # only presentation on /progress. Built entirely in Ruby (Time.zone-aware
  # date ranges, one query, grouped in memory) to avoid the PG date-arithmetic
  # UTC-drift trap this codebase has hit before.
  def build_rating_trends
    rating_habits = Habit.for_user(Current.user).kept.rating.ordered
    return [] if rating_habits.empty?

    today = Date.current
    window_start = 13.days.ago.to_date

    entries = HabitEntry.joins(:daily_log, :habit)
      .where(habits: { id: rating_habits.map(&:id) },
             daily_logs: { date: window_start..today, user_id: Current.user.id })
      .pluck(:habit_id, "daily_logs.date", :value)

    entries_by_habit = entries.group_by { |habit_id, _date, _value| habit_id }

    rating_habits.map do |habit|
      values_by_date = (entries_by_habit[habit.id] || []).each_with_object({}) do |(_habit_id, date, value), hash|
        hash[date] = value.to_f
      end

      points = (window_start..today).map { |date| [ date, values_by_date[date] ] }

      {
        habit: habit,
        avg7: average_for(values_by_date, (today - 6)..today),
        prev_avg7: average_for(values_by_date, (today - 13)..(today - 7)),
        points: points
      }
    end
  end

  def average_for(values_by_date, range)
    values = range.filter_map { |date| values_by_date[date] }
    return nil if values.empty?

    (values.sum / values.size).round(1)
  end
end
