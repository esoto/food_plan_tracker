class Plan < ApplicationRecord
  include Tenantable

  EXERCISE_SLUG = "exercise".freeze
  ACTIVE_SLUG   = "active".freeze
  REST_SLUG     = "rest".freeze

  has_many :meals, -> { order(:position) }, dependent: :destroy, inverse_of: :plan
  has_many :daily_logs, dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :user_id }
  validates :target_kcal, :target_protein_g, :target_carbs_g, :target_fat_g,
            presence: true, numericality: { greater_than: 0 }

  # Highest to lowest demand: Exercise → Active → Rest.
  scope :ordered, -> { in_order_of(:slug, [ EXERCISE_SLUG, ACTIVE_SLUG, REST_SLUG ]) }

  def self.exercise(user: Current.user)
    for_user(user).find_by(slug: EXERCISE_SLUG)
  end

  def self.active(user: Current.user)
    for_user(user).find_by(slug: ACTIVE_SLUG)
  end

  def self.rest(user: Current.user)
    for_user(user).find_by(slug: REST_SLUG)
  end

  def self.find_by_slug!(slug, user: Current.user)
    for_user(user).find_by!(slug: slug)
  end

  def exercise?
    slug == EXERCISE_SLUG
  end
end
