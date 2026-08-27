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

    # Per-day denominator AND numerator both go through the same
    # kept_on(l.date).scoreable scope — so a habit logged done then archived
    # the same day drops out of both sides together, instead of leaving a
    # stale numerator entry that inflates that day's (and the week's
    # average) adherence past 100%. Kept per-day (rather than one grouped
    # query across the range) because kept_on's cutoff is a Ruby
    # Time-zone-aware `date.end_of_day` — reimplementing that in raw SQL
    # against daily_logs.date risks a timezone mismatch with the Ruby side.
    pcts = logs.map do |l|
      scoreable_kept = Habit.for_user(@user).kept_on(l.date).scoreable
      total = scoreable_kept.count
      next 0 if total.zero?

      done = l.habit_entries.joins(:habit).merge(scoreable_kept)
        .where(Habit::DONE_PREDICATE).count
      done * 100.0 / total
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
