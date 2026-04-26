class WeeklySummary
  attr_reader :start_date, :end_date

  def self.rolling_7_days(today: Date.current)
    new((today - 6)..today)
  end

  def initialize(date_range)
    @range      = date_range
    @start_date = date_range.first
    @end_date   = date_range.last
  end

  def adherence_pct
    return nil if logs.empty?

    template_count = ChecklistTemplate.count
    return 0 if template_count.zero?

    checked_per_log = ChecklistCompletion.where(daily_log: logs, checked: true).group(:daily_log_id).count
    avg_pct = logs.sum { |l| checked_per_log.fetch(l.id, 0) * 100.0 / template_count } / logs.size
    avg_pct.round
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
    supplement_count = Supplement.count
    return nil if supplement_count.zero?

    expected = supplement_count * @range.count
    completed = SupplementCompletion.where(daily_log: logs).count
    ((completed.to_f / expected) * 100).round
  end

  private

  def logs
    @logs ||= DailyLog.where(date: @range).includes(plan: :meals).to_a
  end

  def weight_goal
    @weight_goal ||= Goal.find_by(metric: Goal.metrics[:weight_kg])
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
