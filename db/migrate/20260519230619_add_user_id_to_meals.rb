class AddUserIdToMeals < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :meals, :user_id, :bigint
    add_index :meals, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :meals, :user_id, algorithm: :concurrently
    remove_column :meals, :user_id
  end
end
