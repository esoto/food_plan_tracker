class DailyLogsController < ApplicationController
  def update
    log = DailyLog.find(params[:id])
    log.update!(daily_log_params)
    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def daily_log_params
    params.require(:daily_log).permit(:plan_id, :weight_kg, :notes)
  end
end
