class BackfillFoodTrackingEnabled < ActiveRecord::Migration[8.1]
  # Pre-flag users always had food tracking; new users default to off.
  def up
    execute("UPDATE users SET food_tracking_enabled = TRUE")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
