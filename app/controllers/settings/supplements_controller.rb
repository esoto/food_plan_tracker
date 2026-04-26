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
      sync_schedules(@supplement, params[:time_slots] || [])
      redirect_to settings_supplements_path, notice: "Added \"#{@supplement.name}\""
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @supplement.update(supplement_params)
      sync_schedules(@supplement, params[:time_slots] || [])
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

  # Reconcile time-slot pivot rows against checked checkboxes. Newly checked
  # slots get a row appended at the end of that slot's existing positions;
  # newly unchecked slots have their row deleted. Position within each slot
  # is otherwise preserved.
  def sync_schedules(supplement, requested_slots)
    requested = requested_slots.map(&:to_s).to_set & SupplementSchedule::TIME_SLOTS.keys.map(&:to_s)
    existing = supplement.supplement_schedules.index_by(&:time_slot)

    (requested - existing.keys).each do |slot|
      next_position = (SupplementSchedule.where(time_slot: slot).maximum(:position) || -1) + 1
      supplement.supplement_schedules.create!(time_slot: slot, position: next_position)
    end

    (existing.keys - requested.to_a).each do |slot|
      existing[slot].destroy!
    end
  end
end
