class AddUserIdToLoggedFoods < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  # NOTE: PER-553 backfill must run after daily_logs.user_id is populated.

  def up
    add_column :logged_foods, :user_id, :bigint, if_not_exists: true
    add_index :logged_foods, :user_id, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :logged_foods, :user_id, algorithm: :concurrently, if_exists: true
    remove_column :logged_foods, :user_id, if_exists: true
  end
end
