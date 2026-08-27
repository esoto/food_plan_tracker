class DailyLog < ApplicationRecord
  include Tenantable

  belongs_to :plan

  has_many :meal_completions, dependent: :destroy
  has_many :completed_meals, through: :meal_completions, source: :meal
  has_many :supplement_completions, dependent: :destroy
  has_many :completed_supplements, through: :supplement_completions, source: :supplement
  has_many :habit_entries, dependent: :destroy
  has_many :logged_foods, -> { order(logged_at: :desc) }, dependent: :destroy

  validates :date, presence: true, uniqueness: { scope: :user_id }

  scope :chronological, -> { order(:date) }
  scope :recent, ->(n) { order(date: :desc).limit(n) }

  def self.for(positional_date = nil, positional_user = nil, user: nil, default_plan: nil)
    if positional_date.is_a?(Date)
      date = positional_date
      actual_user = user || positional_user || Current.user
    elsif positional_date.present?
      # Backward-compatible: DailyLog.for(Current.user, date)
      actual_user = positional_date
      date = positional_user || Date.current
    else
      raise ArgumentError, "date is required"
    end

    default_plan ||= Plan.active(user: actual_user) || Plan.exercise(user: actual_user) || Plan.for_user(actual_user).ordered.first
    for_user(actual_user).find_or_create_by!(date: date) { |log| log.plan = default_plan }
  end

  def self.today(positional_user = nil, user: nil)
    actual_user = positional_user || user || Current.user
    self.for(Date.current, user: actual_user)
  end

  def self.yesterday(user: Current.user)
    for_user(user).find_by(date: Date.yesterday)
  end

  def self.recent(n, user: Current.user)
    for_user(user).chronological.recent(n)
  end

  # Authorization: copying across plans is meaningless because meal_ids differ.
  def can_copy_from?(other)
    other.present? && other.plan_id == plan_id
  end

  # Presentation: is there anything worth copying? Used to decide whether
  # the menu surfaces the "Log same as yesterday" button.
  def has_uncopied_completions_from?(other)
    return false unless can_copy_from?(other)

    other_count = other.meal_completions.size
    other_count.positive? && other_count > meal_completions.size
  end

  # Copies completions from `other` onto self, skipping meals already
  # marked complete here. Returns the number actually inserted. Atomic.
  def copy_completions_from(other)
    existing = meal_completions.pluck(:meal_id)
    to_copy = other.meal_completions.where.not(meal_id: existing).pluck(:meal_id)

    transaction do
      to_copy.each { |meal_id| meal_completions.create!(meal_id: meal_id, completed_at: Time.current) }
    end

    to_copy.size
  end

  def consumed_kcal
    (completed_meals.sum(:target_kcal) + logged_foods.sum(&:kcal)).to_i
  end

  def consumed_protein_g
    (completed_meals.sum(:target_protein_g).to_f + logged_foods.sum(&:protein_g).to_f).round(1)
  end

  def consumed_carbs_g
    (completed_meals.sum(:target_carbs_g).to_f + logged_foods.sum(&:carbs_g).to_f).round(1)
  end

  def consumed_fat_g
    (completed_meals.sum(:target_fat_g).to_f + logged_foods.sum(&:fat_g).to_f).round(1)
  end

  def habit_adherence_pct
    total = Habit.for_user(user).kept_on(date).scoreable.count
    return 0 if total.zero?

    done = habit_entries.joins(:habit).merge(Habit.scoreable)
      .where(Habit::DONE_PREDICATE).count
    ((done.to_f / total) * 100).round
  end
end
