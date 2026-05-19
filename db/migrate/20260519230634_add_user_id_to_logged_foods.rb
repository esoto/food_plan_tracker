class AddUserIdToLoggedFoods < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :logged_foods, :user_id, :bigint
    add_index :logged_foods, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :logged_foods, :user_id, algorithm: :concurrently
    remove_column :logged_foods, :user_id
  end
end
