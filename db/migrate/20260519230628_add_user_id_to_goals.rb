class AddUserIdToGoals < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :goals, :user_id, :bigint, if_not_exists: true
    add_index :goals, :user_id, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :goals, :user_id, algorithm: :concurrently, if_exists: true
    remove_column :goals, :user_id, if_exists: true
  end
end
