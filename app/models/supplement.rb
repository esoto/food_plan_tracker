class Supplement < ApplicationRecord
  include Discardable

  has_many :supplement_schedules, dependent: :destroy
  has_many :supplement_completions, dependent: :destroy

  validates :name, :dose, presence: true

  scope :critical_first, -> { order(critical: :desc, id: :asc) }

  # Reconcile the time_slot pivot rows against `requested` (an array of slot
  # keys, e.g. ["morning", "dinner"]). Newly checked slots get appended at
  # the end of that slot's existing positions; newly unchecked slots have
  # their row destroyed. Position within each slot is preserved across
  # saves. Wrapped in a transaction so a partial failure rolls back.
  def sync_time_slots!(requested)
    requested = Array(requested).map(&:to_s).to_set & SupplementSchedule::TIME_SLOTS.keys.map(&:to_s)
    existing  = supplement_schedules.index_by(&:time_slot)

    transaction do
      (requested - existing.keys).each do |slot|
        next_position = (SupplementSchedule.where(time_slot: slot).maximum(:position) || -1) + 1
        supplement_schedules.create!(time_slot: slot, position: next_position)
      end
      (existing.keys - requested.to_a).each do |slot|
        existing[slot].destroy!
      end
    end
  end
end
