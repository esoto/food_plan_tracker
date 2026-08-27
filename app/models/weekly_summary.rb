class WeeklySummary
  attr_reader :start_date, :end_date, :user

  def self.rolling_7_days(today: Date.current, user: Current.user)
    new((today - 6)..today, user: user)
  end

  def initialize(date_range, user: Current.user)
    @range      = date_range
    @user       = user
    @start_date = date_range.first
    @end_date   = date_range.last
  end

  def adherence_pct
    return nil if logs.empty?

    # Per-day denominator from templates that were active on that date — so
    # archiving a habit today doesn't retroactively shift past percentages.
    done_per_log = HabitEntry.joins(:habit).merge(Habit.scoreable)
      .where(daily_log: logs).where(Habit::DONE_PREDICATE)
      .group(:daily_log_id).count

    totals_per_date = logs.each_with_object(Hash.new(0)) do |l, h|
      h[l.date] = Habit.for_user(@user).kept_on(l.date).scoreable.count
    end

    pcts = logs.map do |l|
      total = totals_per_date[l.date] || 0
      next 0 if total.zero?

      done_per_log.fetch(l.id, 0) * 100.0 / total
    end
    (pcts.sum / pcts.size).round
  end

  def weight_delta_kg
    return nil unless start_weight && end_weight

    (end_weight - start_weight).round(1)
  end

  def meal_completion_pct
    expected = logs.sum { |l| l.plan.meals.count }
    return nil if expected.zero?

    completed = MealCompletion.where(daily_log: logs).count
    ((completed.to_f / expected) * 100).round
  end

  def supplement_completion_pct
    # Per-day expected from supplements active on that date — same rationale
    # as adherence_pct: don't rewrite history when one is archived.
    expected = @range.sum { |d| Supplement.for_user(@user).kept_on(d).count }
    return nil if expected.zero?

    completed = SupplementCompletion.where(daily_log: logs).count
    ((completed.to_f / expected) * 100).round
  end

  private

  def logs
    @logs ||= DailyLog.for_user(@user).where(date: @range).includes(plan: :meals).to_a
  end

  def weight_goal
    @weight_goal ||= Goal.for_user(@user).find_by(metric: Goal.metrics[:weight_kg])
  end

  def start_weight
    return @start_weight if defined?(@start_weight)

    @start_weight = weight_on_or_before(@start_date)
  end

  def end_weight
    return @end_weight if defined?(@end_weight)

    @end_weight = weight_on_or_before(@end_date)
  end

  def weight_on_or_before(date)
    weight_goal&.biomarker_entries
              &.where("recorded_on <= ?", date)
              &.order(:recorded_on)
              &.last
              &.value
              &.to_f
  end
end
