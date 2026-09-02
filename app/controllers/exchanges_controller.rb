class ExchangesController < ApplicationController
  include RequiresFoodTrackingHtml

  def index
    @category = (params[:category] || "protein").to_s
    @category = "protein" unless Food.categories.key?(@category)
    @query = params[:q].to_s.strip
    scope = Food.where(category: @category).alphabetical
    scope = scope.where("name ILIKE ?", "%#{@query}%") if @query.present?
    @foods = scope

    # When the user reached this page from /days/:date, daily_log_id rides
    # on the URL so the "+ Log" forms target that day instead of today.
    @target_log = Current.user.daily_logs.find_by(id: params[:daily_log_id]) if params[:daily_log_id].present?
  end
end
