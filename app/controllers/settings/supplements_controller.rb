class Settings::SupplementsController < ApplicationController
  before_action :set_supplement, only: %i[edit update destroy restore]

  def index
    @supplements = Supplement.kept.order(critical: :desc, name: :asc).includes(:supplement_schedules)
  end

  def archived
    @supplements = Supplement.discarded.order(:name)
  end

  def new
    @supplement = Supplement.new
  end

  def create
    @supplement = Supplement.new(supplement_params)
    if @supplement.save
      @supplement.sync_time_slots!(params[:time_slots]) if params.key?(:time_slots)
      redirect_to settings_supplements_path, notice: "Added \"#{@supplement.name}\""
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @supplement.update(supplement_params)
      @supplement.sync_time_slots!(params[:time_slots]) if params.key?(:time_slots)
      redirect_to settings_supplements_path, notice: "Updated \"#{@supplement.name}\""
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @supplement.discard!
    redirect_to settings_supplements_path, notice: "Archived \"#{@supplement.name}\""
  end

  def restore
    @supplement.restore!
    redirect_to settings_supplements_path, notice: "Restored \"#{@supplement.name}\""
  end

  private

  def set_supplement
    @supplement = Supplement.find(params[:id])
  end

  def supplement_params
    params.require(:supplement).permit(:name, :dose, :critical, :notes, :contraindications)
  end
end
