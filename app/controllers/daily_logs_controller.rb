class DailyLogsController < ApplicationController
  def update
    log = Current.user.daily_logs.find(params[:id])
    log.update!(daily_log_params)
    redirect_back fallback_location: root_path, status: :see_other
  end

  private

  def daily_log_params
    params.require(:daily_log).permit(:plan_id, :weight_kg, :notes).tap do |p|
      # Reject a plan the current user doesn't own (raises RecordNotFound → 404).
      Current.user.plans.find(p[:plan_id]) if p[:plan_id].present?
    end
  end
end
