class BackfillHabitEntryValues < ActiveRecord::Migration[8.1]
  def up
    execute("UPDATE habit_entries SET value = 1.0 WHERE checked = true")
  end

  def down
    # checked remains authoritative for rollback until it is dropped post-bake;
    # un-backfilling value would lose quantity/duration data written after deploy.
    raise ActiveRecord::IrreversibleMigration
  end
end
