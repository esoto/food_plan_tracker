class BiomarkerEntry < ApplicationRecord
  include Tenantable

  belongs_to :goal, inverse_of: :biomarker_entries

  validates :recorded_on, :value, presence: true
  validates :value, numericality: true

  scope :chronological, -> { order(:recorded_on) }
end
