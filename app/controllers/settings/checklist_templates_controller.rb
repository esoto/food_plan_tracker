class Settings::ChecklistTemplatesController < ApplicationController
  before_action :set_template, only: %i[edit update destroy restore move_up move_down]

  def index
    @templates = ChecklistTemplate.kept.ordered
  end

  def archived
    @templates = ChecklistTemplate.discarded.order(:label)
  end

  def new
    @template = ChecklistTemplate.new(position: ChecklistTemplate.next_position)
  end

  def create
    @template = ChecklistTemplate.new(template_params)
    @template.position = ChecklistTemplate.next_position
    if @template.save
      redirect_to settings_habits_path, notice: "Added \"#{@template.label}\""
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      redirect_to settings_habits_path, notice: "Updated \"#{@template.label}\""
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @template.discard!
    redirect_to settings_habits_path, notice: "Archived \"#{@template.label}\""
  end

  def restore
    @template.restore_at_end!
    redirect_to settings_habits_path, notice: "Restored \"#{@template.label}\""
  end

  def move_up
    swap_position(@template, direction: :up)
    redirect_to settings_habits_path
  end

  def move_down
    swap_position(@template, direction: :down)
    redirect_to settings_habits_path
  end

  private

  def set_template
    @template = ChecklistTemplate.find(params[:id])
  end

  def template_params
    params.require(:checklist_template).permit(:label, :description, :icon)
  end

  # Swap the `position` value with the adjacent kept template. Position is the
  # only column changed — IDs and FKs are untouched.
  def swap_position(template, direction:)
    siblings = ChecklistTemplate.kept.ordered.to_a
    idx = siblings.index { |t| t.id == template.id }
    return unless idx

    target_idx = direction == :up ? idx - 1 : idx + 1
    return if target_idx < 0 || target_idx >= siblings.size

    other = siblings[target_idx]
    ChecklistTemplate.transaction do
      a_pos, b_pos = template.position, other.position
      template.update!(position: b_pos)
      other.update!(position: a_pos)
    end
  end
end
