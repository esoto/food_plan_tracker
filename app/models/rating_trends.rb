# Ratings are walled out of adherence/streak/heatmap by design — trends
# (7-day avg, delta vs the prior 7 days, and a 14-day sparkline) are their
# only presentation on /progress. Built entirely in Ruby (Time.zone-aware
# date ranges, one query, grouped in memory) to avoid the PG date-arithmetic
# UTC-drift trap this codebase has hit before.
class RatingTrends
  def self.for(user, today: Date.current)
    rating_habits = Habit.for_user(user).kept.rating.ordered
    return [] if rating_habits.empty?

    window_start = today - 13

    entries = HabitEntry.joins(:daily_log, :habit)
      .where(habits: { id: rating_habits.map(&:id) },
             daily_logs: { date: window_start..today, user_id: user.id })
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

  def self.average_for(values_by_date, range)
    values = range.filter_map { |date| values_by_date[date] }
    return nil if values.empty?

    (values.sum / values.size).round(1)
  end
  private_class_method :average_for
end
