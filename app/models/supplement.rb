class Supplement < ApplicationRecord
  include Discardable

  has_many :supplement_schedules, dependent: :destroy
  has_many :supplement_completions, dependent: :destroy

  validates :name, :dose, presence: true

  scope :critical_first, -> { order(critical: :desc, id: :asc) }
end
