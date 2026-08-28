class Habit < ApplicationRecord
  include Discardable, Tenantable

  has_many :habit_entries, dependent: :destroy

  enum :kind, { binary: 0, quantity: 1, duration: 2, rating: 3 }, default: :binary

  # kind is an enum — EnumType casts a blank string ("") to nil, which would
  # otherwise sail past this validation and hit the column's NOT NULL
  # constraint as an unrescued 500 on any surface that doesn't pre-guard the
  # raw param (the MCP create_habit handler didn't). RecordInvalid from this
  # validation is a normal, rescued client-input error on every surface.
  validates :label, :position, :kind, presence: true
  validates :target_value, numericality: { greater_than: 0 }, allow_nil: true
  validates :rating_scale, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: 10 },
    if: :rating?
  validates :rating_scale, absence: true, unless: :rating?
  validates :target_value, absence: true, if: :rating?
  validates :unit, absence: true, if: -> { binary? || rating? }

  scope :ordered, -> { order(:position) }
  # Ratings are measurements, not pass/fail — walled out of adherence/streak/heatmap.
  scope :scoreable, -> { where.not(kind: :rating) }

  # All-or-nothing done-ness; nil target falls back to any positive value.
  DONE_PREDICATE = <<~SQL.squish.freeze
    CASE WHEN habits.target_value IS NULL THEN habit_entries.value > 0
         ELSE habit_entries.value >= habits.target_value END
  SQL

  # Shared predicate for the "is this a recognized kind key" guard duplicated
  # across the create paths that accept a raw (possibly bogus) kind param.
  def self.valid_kind?(value) = kinds.key?(value.to_s)

  # Next position to use for a newly created or restored kept habit.
  def self.next_position(user: Current.user)
    (for_user(user).kept.maximum(:position) || -1) + 1
  end

  # Restore a discarded habit at the end of the current order. Position
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
