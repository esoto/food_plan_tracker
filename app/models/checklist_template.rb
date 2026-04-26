class ChecklistTemplate < ApplicationRecord
  include Discardable

  has_many :checklist_completions, dependent: :destroy

  validates :label, :position, presence: true

  scope :ordered, -> { order(:position) }
end
