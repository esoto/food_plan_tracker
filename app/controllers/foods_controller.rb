class FoodsController < ApplicationController
  include RequiresFoodTrackingHtml

  def new
    @food = Food.new(category: requested_category)
  end

  def create
    @food = Food.new(food_params)
    if @food.save
      redirect_to exchanges_path(category: @food.category), status: :see_other,
                  notice: "Added #{@food.name}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def requested_category
    cat = params[:category].to_s
    Food.categories.key?(cat) ? cat : "protein"
  end

  def food_params
    params.require(:food).permit(:name, :category, :serving_grams, :kcal,
                                 :protein_g, :carbs_g, :fat_g, :notes)
  end
end
