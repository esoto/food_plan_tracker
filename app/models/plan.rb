class Plan < ApplicationRecord
  CROSSFIT_SLUG = "crossfit".freeze
  REST_SLUG = "rest".freeze

  has_many :meals, -> { order(:position) }, dependent: :destroy, inverse_of: :plan
  has_many :daily_logs, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  validates :target_kcal, :target_protein_g, :target_carbs_g, :target_fat_g,
            presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:id) }

  def self.crossfit
    find_by(slug: CROSSFIT_SLUG)
  end

  def self.rest
    find_by(slug: REST_SLUG)
  end

  def crossfit?
    slug == CROSSFIT_SLUG
  end
end
