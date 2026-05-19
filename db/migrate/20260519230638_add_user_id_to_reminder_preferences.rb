class AddUserIdToReminderPreferences < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :reminder_preferences, :user_id, :bigint
    add_index :reminder_preferences, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :reminder_preferences, :user_id, algorithm: :concurrently
    remove_column :reminder_preferences, :user_id
  end
end
