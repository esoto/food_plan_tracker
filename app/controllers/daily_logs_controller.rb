class DailyLogsController < ApplicationController
  def update
    log = Current.user.daily_logs.find(params[:id])
    log.update!(daily_log_params)
    redirect_back fallback_location: root_path, status: :see_other
  end

  private

  def daily_log_params
    permitted = params.require(:daily_log).permit(:plan_id, :weight_kg, :notes)
    # Reject a plan the current user doesn't own (raises RecordNotFound → 404).
    Current.user.plans.find(permitted[:plan_id]) if permitted[:plan_id].present?
    permitted
  end
end
