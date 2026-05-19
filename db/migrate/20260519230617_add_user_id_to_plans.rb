class AddUserIdToPlans < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :plans, :user_id, :bigint
    add_index :plans, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :plans, :user_id, algorithm: :concurrently
    remove_column :plans, :user_id
  end
end
