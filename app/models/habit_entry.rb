class HabitEntry < ApplicationRecord
  class InvalidValue < StandardError; end

  belongs_to :daily_log
  belongs_to :habit

  validates :habit_id, uniqueness: { scope: :daily_log_id }
  validates :value, numericality: { greater_than_or_equal_to: 0 }

  # All entry writes go through these two so `checked` stays consistent for the
  # one-cycle rollback window (upsert/raw SQL skip AR callbacks — the dual-write
  # MUST live in the SQL). Drop `checked` handling with the column post-bake.
  def self.set_value!(daily_log:, habit:, value:)
    value = validate_value!(habit, value)
    upsert(
      { daily_log_id: daily_log.id, habit_id: habit.id,
        value: value, checked: value > 0 },
      unique_by: %i[daily_log_id habit_id]
    )
  end

  def self.increment_value!(daily_log:, habit:, delta:)
    raise InvalidValue, "delta must be numeric" unless delta.is_a?(Numeric)

    # NOTE: the DO UPDATE branch re-binds the raw `delta` rather than reading
    # EXCLUDED.value — EXCLUDED.value is already floored by the VALUES clause's
    # GREATEST(0, ?), so a negative delta routed through EXCLUDED would collapse
    # to 0 before it could offset the existing value (e.g. 2 then -5 would land
    # on 2, not 0). Using the raw delta here keeps the floor-at-0 semantics
    # correct for decrements against an existing row.
    sql = sanitize_sql_array([<<~SQL, daily_log.id, habit.id, delta, delta, delta, delta])
      INSERT INTO habit_entries (daily_log_id, habit_id, value, checked, created_at, updated_at)
      VALUES (?, ?, GREATEST(0, ?), GREATEST(0, ?) > 0, NOW(), NOW())
      ON CONFLICT (daily_log_id, habit_id) DO UPDATE
        SET value = GREATEST(0, habit_entries.value + ?),
            checked = GREATEST(0, habit_entries.value + ?) > 0,
            updated_at = NOW()
    SQL
    connection.execute(sql)
  end

  def self.validate_value!(habit, value)
    value = value.to_f
    raise InvalidValue, "value must be >= 0" if value.negative?
    if habit.rating? && (value < 0 || value > habit.rating_scale)
      raise InvalidValue, "rating must be within 0..#{habit.rating_scale}"
    end
    value
  end
  private_class_method :validate_value!
end
