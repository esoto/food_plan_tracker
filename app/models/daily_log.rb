class DailyLog < ApplicationRecord
  belongs_to :plan

  has_many :meal_completions, dependent: :destroy
  has_many :completed_meals, through: :meal_completions, source: :meal
  has_many :supplement_completions, dependent: :destroy
  has_many :completed_supplements, through: :supplement_completions, source: :supplement
  has_many :checklist_completions, dependent: :destroy
  has_many :logged_foods, -> { order(logged_at: :desc) }, dependent: :destroy

  validates :date, presence: true, uniqueness: true

  scope :chronological, -> { order(:date) }
  scope :recent, ->(n) { order(date: :desc).limit(n) }

  def self.for(date, default_plan: Plan.active || Plan.exercise || Plan.ordered.first)
    find_or_create_by!(date: date) { |log| log.plan = default_plan }
  end

  def self.today
    self.for(Date.current)
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

  def checklist_adherence_pct
    total = ChecklistTemplate.count
    return 0 if total.zero?

    checked = checklist_completions.where(checked: true).count
    ((checked.to_f / total) * 100).round
  end
end
