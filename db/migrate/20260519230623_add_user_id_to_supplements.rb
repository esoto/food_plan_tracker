class AddUserIdToSupplements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :supplements, :user_id, :bigint
    add_index :supplements, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :supplements, :user_id, algorithm: :concurrently
    remove_column :supplements, :user_id
  end
end
