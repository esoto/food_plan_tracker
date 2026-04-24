class ExchangesController < ApplicationController
  def index
    @category = (params[:category] || "protein").to_s
    @category = "protein" unless Food.categories.key?(@category)
    @query = params[:q].to_s.strip
    scope = Food.public_send(@category).alphabetical
    scope = scope.where("name LIKE ?", "%#{@query}%") if @query.present?
    @foods = scope
  end
end
