class AddUserIdToMealItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :meal_items, :user_id, :bigint
    add_index :meal_items, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :meal_items, :user_id, algorithm: :concurrently
    remove_column :meal_items, :user_id
  end
end
