class Plan < ApplicationRecord
  EXERCISE_SLUG = "exercise".freeze
  ACTIVE_SLUG   = "active".freeze
  REST_SLUG     = "rest".freeze

  has_many :meals, -> { order(:position) }, dependent: :destroy, inverse_of: :plan
  has_many :daily_logs, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  validates :target_kcal, :target_protein_g, :target_carbs_g, :target_fat_g,
            presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:id) }

  def self.exercise
    find_by(slug: EXERCISE_SLUG)
  end

  def self.active
    find_by(slug: ACTIVE_SLUG)
  end

  def self.rest
    find_by(slug: REST_SLUG)
  end

  def exercise?
    slug == EXERCISE_SLUG
  end
end
