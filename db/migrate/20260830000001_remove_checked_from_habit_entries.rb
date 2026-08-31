class RemoveCheckedFromHabitEntries < ActiveRecord::Migration[8.1]
  def change
    # Dual-write window (PR #100) has run in production for 3+ days and the
    # backfill is verified complete (0 rows with checked=true and value=0, and
    # vice versa). `value` is now the single source of truth for habit_entries.
    # Reversible: `down` re-adds the column with its original shape, but the
    # historical checked/unchecked values are NOT restored — a re-added
    # column comes back with defaults only (checked: false for every row).
    remove_column :habit_entries, :checked, :boolean, default: false, null: false
  end
end
