class SupplementCompletionsController < ApplicationController
  before_action :set_daily_log, only: :create

  def create
    supplement = Supplement.find(params[:supplement_id])
    @daily_log.supplement_completions.find_or_create_by!(supplement: supplement) { |sc| sc.taken_at = Time.current }
    redirect_back fallback_location: supplements_path
  end

  def destroy
    completion = SupplementCompletion.find(params[:id])
    completion.destroy!
    redirect_back fallback_location: supplements_path
  end

  private

  def set_daily_log
    @daily_log = today_log
  end
end
