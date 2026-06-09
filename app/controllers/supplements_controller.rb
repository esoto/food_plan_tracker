class SupplementsController < ApplicationController
  def show
    @daily_log = today_log
    kept_supplements = Current.user.supplements.kept
    @grouped = Current.user.supplement_schedules
      .joins(:supplement)
      .merge(kept_supplements)
      .includes(:supplement)
      .order(:time_slot, :position)
      .group_by(&:time_slot)
    @taken_ids = @daily_log.supplement_completions.pluck(:supplement_id)
    @critical_warnings = kept_supplements.where(critical: true)
  end
end
