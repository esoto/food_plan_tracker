class AddValueToHabitEntries < ActiveRecord::Migration[8.1]
  def change
    # PG11+ fast-default: instant on existing rows.
    add_column :habit_entries, :value, :decimal, precision: 6, scale: 2, default: 0.0, null: false
  end
end
