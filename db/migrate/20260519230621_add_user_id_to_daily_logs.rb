class AddUserIdToDailyLogs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :daily_logs, :user_id, :bigint, if_not_exists: true
    add_index :daily_logs, :user_id, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :daily_logs, :user_id, algorithm: :concurrently, if_exists: true
    remove_column :daily_logs, :user_id, if_exists: true
  end
end
