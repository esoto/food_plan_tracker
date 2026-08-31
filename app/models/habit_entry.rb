class HabitEntry < ApplicationRecord
  class InvalidValue < StandardError; end

  # value is decimal(6,2) — the column can hold at most 4 integer digits, so
  # the largest representable magnitude is 9999.99. Anything past that must
  # be rejected as a client-input InvalidValue before it reaches SQL; letting
  # it through raises an unrescued ActiveRecord::RangeError (PG::NumericValueOutOfRange).
  MAX_VALUE = 9999.99

  belongs_to :daily_log
  belongs_to :habit

  validates :habit_id, uniqueness: { scope: :daily_log_id }
  validates :value, numericality: { greater_than_or_equal_to: 0 }

  # All entry writes go through these two. `value` is the single source of
  # truth (the legacy `checked` column and its dual-write were removed
  # post-bake); upsert/raw SQL below skip AR callbacks, so any future derived
  # column would again need to live in the SQL, not a model callback.
  def self.set_value!(daily_log:, habit:, value:)
    value = validate_value!(habit, value)
    upsert(
      { daily_log_id: daily_log.id, habit_id: habit.id, value: value },
      unique_by: %i[daily_log_id habit_id]
    )
  end

  def self.increment_value!(daily_log:, habit:, delta:)
    raise InvalidValue, "delta must be numeric" unless delta.is_a?(Numeric)
    raise InvalidValue, "increment is not supported for rating habits" if habit.rating?
    raise InvalidValue, "value must be <= #{MAX_VALUE}" if delta.abs > MAX_VALUE

    # NOTE: the DO UPDATE branch re-binds the raw `delta` rather than reading
    # EXCLUDED.value — EXCLUDED.value is already floored by the VALUES clause's
    # GREATEST(0, ?), so a negative delta routed through EXCLUDED would collapse
    # to 0 before it could offset the existing value (e.g. 2 then -5 would land
    # on 2, not 0). Using the raw delta here keeps the floor-at-0 semantics
    # correct for decrements against an existing row.
    sql = sanitize_sql_array([<<~SQL, daily_log.id, habit.id, delta, delta])
      INSERT INTO habit_entries (daily_log_id, habit_id, value, created_at, updated_at)
      VALUES (?, ?, GREATEST(0, ?), NOW(), NOW())
      ON CONFLICT (daily_log_id, habit_id) DO UPDATE
        SET value = GREATEST(0, habit_entries.value + ?),
            updated_at = NOW()
    SQL
    # requires_new: true opens a SAVEPOINT around the raw execute. A PG
    # overflow error marks the *current* transaction aborted; without a
    # savepoint boundary that would poison the caller's outer transaction
    # (e.g. RSpec's per-test transactional fixture) for every query after
    # this one, not just this statement. The savepoint rolls back only this
    # statement, leaving the outer transaction (and the existing row) intact.
    transaction(requires_new: true) { connection.execute(sql) }
  rescue ActiveRecord::RangeError
    # The per-delta guard above catches an obviously-too-large single delta,
    # but a small delta can still push an already-large existing value past
    # the column's range (e.g. 9999 + 1). Postgres itself is the only source
    # of truth for that accumulated total, so any overflow it reports is
    # normalized to the same client-input InvalidValue rather than leaking a
    # raw ActiveRecord::RangeError / PG::NumericValueOutOfRange up the stack.
    raise InvalidValue, "value must be <= #{MAX_VALUE}"
  end

  def self.validate_value!(habit, value)
    value = value.to_f
    raise InvalidValue, "value must be >= 0" if value.negative?
    raise InvalidValue, "value must be <= #{MAX_VALUE}" if value > MAX_VALUE
    if habit.rating? && (value < 0 || value > habit.rating_scale)
      raise InvalidValue, "rating must be within 0..#{habit.rating_scale}"
    end
    value
  end
  private_class_method :validate_value!
end
