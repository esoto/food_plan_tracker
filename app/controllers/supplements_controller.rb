class SupplementsController < ApplicationController
  def show
    @daily_log = today_log
    @grouped = SupplementSchedule
      .includes(:supplement)
      .order(:time_slot, :position)
      .group_by(&:time_slot)
    @taken_ids = @daily_log.supplement_completions.pluck(:supplement_id)
    @critical_warnings = Supplement.where(critical: true)
  end
end
