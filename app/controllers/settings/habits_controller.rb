class Settings::HabitsController < ApplicationController
  before_action :set_habit, only: %i[edit update destroy restore move_up move_down]

  def index
    @habits = Current.user.habits.kept.ordered
  end

  def archived
    @habits = Current.user.habits.discarded.order(:label)
  end

  def new
    @habit = Habit.new(position: Habit.next_position(user: Current.user))
  end

  def create
    # kind is an enum — Habit.new would raise ArgumentError on an unrecognized
    # value, which is a client input problem, not a server error. Validate it
    # against the enum's known keys up front rather than rescuing broadly.
    # Checked whenever the :kind KEY is present (not merely non-blank) —
    # EnumType casts a blank string to nil, which would otherwise slip past
    # a `.present?` check and hit the kind NOT NULL constraint as a 500.
    if create_habit_params.key?(:kind) && !Habit.kinds.key?(create_habit_params[:kind].to_s)
      @habit = Habit.new(create_habit_params.except(:kind))
      @habit.errors.add(:kind, "is not a valid kind")
      return render :new, status: :unprocessable_entity
    end

    @habit = Habit.new(create_habit_params)
    @habit.position = Habit.next_position(user: Current.user)
    if @habit.save
      redirect_to settings_habits_path, notice: "Added \"#{@habit.label}\""
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @habit.update(update_habit_params)
      redirect_to settings_habits_path, notice: "Updated \"#{@habit.label}\""
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @habit.discard!
    redirect_to settings_habits_path, notice: "Archived \"#{@habit.label}\""
  end

  def restore
    @habit.restore_at_end!
    redirect_to settings_habits_path, notice: "Restored \"#{@habit.label}\""
  end

  def move_up
    swap_position(@habit, direction: :up)
    redirect_to settings_habits_path
  end

  def move_down
    swap_position(@habit, direction: :down)
    redirect_to settings_habits_path
  end

  private

  def set_habit
    @habit = Current.user.habits.find(params[:id])
  end

  # kind is a lookup key, not just a value — it's only settable at creation.
  # Changing it under existing entries corrupts semantics (same philosophy
  # as the MCP name rule), so update permits everything except :kind and
  # silently ignores any kind param sent.
  def create_habit_params
    params.require(:habit).permit(:label, :description, :icon, :kind, :unit, :target_value, :rating_scale)
  end

  def update_habit_params
    params.require(:habit).permit(:label, :description, :icon, :unit, :target_value, :rating_scale)
  end

  # Swap the `position` value with the adjacent kept habit. Position is the
  # only column changed — IDs and FKs are untouched.
  def swap_position(habit, direction:)
    siblings = Current.user.habits.kept.ordered.to_a
    idx = siblings.index { |h| h.id == habit.id }
    return unless idx

    target_idx = direction == :up ? idx - 1 : idx + 1
    return if target_idx < 0 || target_idx >= siblings.size

    other = siblings[target_idx]
    Habit.transaction do
      a_pos, b_pos = habit.position, other.position
      habit.update!(position: b_pos)
      other.update!(position: a_pos)
    end
  end
end
