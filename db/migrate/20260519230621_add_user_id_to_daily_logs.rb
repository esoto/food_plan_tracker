class AddUserIdToDailyLogs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :daily_logs, :user_id, :bigint
    add_index :daily_logs, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :daily_logs, :user_id, algorithm: :concurrently
    remove_column :daily_logs, :user_id
  end
end
