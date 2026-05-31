class ChecklistTemplate < ApplicationRecord
  include Discardable, Tenantable

  has_many :checklist_completions, dependent: :destroy

  validates :label, :position, presence: true

  scope :ordered, -> { order(:position) }

  # Next position to use for a newly created or restored kept template.
  def self.next_position(user: Current.user)
    (for_user(user).kept.maximum(:position) || -1) + 1
  end

  # Restore a discarded template at the end of the current order. Position
  # is computed from the *currently kept* set BEFORE clearing discarded_at,
  # so this row appends right after the existing tail (rather than skipping
  # a slot for itself). Atomic — both writes roll back on failure.
  def restore_at_end!
    target_position = self.class.next_position(user: self.user)
    transaction do
      restore!
      update!(position: target_position)
    end
  end
end
