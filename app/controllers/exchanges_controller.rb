class ExchangesController < ApplicationController
  def index
    @category = (params[:category] || "protein").to_s
    @category = "protein" unless Food.categories.key?(@category)
    @query = params[:q].to_s.strip
    scope = Food.where(category: @category).alphabetical
    scope = scope.where("name ILIKE ?", "%#{@query}%") if @query.present?
    @foods = scope
  end
end
