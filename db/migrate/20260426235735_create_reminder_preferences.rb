class CreateReminderPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :reminder_preferences do |t|
      # "meal" or "supplement_slot"
      t.string  :reminder_type, null: false
      # meal name ("Breakfast") or slot key ("morning")
      t.string  :key,           null: false
      t.boolean :enabled,       null: false, default: true

      t.timestamps
    end

    # Unique by (type, key) — one row per reminder. Default behaviour is
    # "enabled" so the table starts empty; rows are inserted on first
    # toggle.
    add_index :reminder_preferences, [ :reminder_type, :key ], unique: true
  end
end
