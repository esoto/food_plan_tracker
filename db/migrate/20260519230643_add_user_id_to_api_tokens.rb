class AddUserIdToApiTokens < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :api_tokens, :user_id, :bigint, if_not_exists: true
    add_index :api_tokens, :user_id, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :api_tokens, :user_id, algorithm: :concurrently, if_exists: true
    remove_column :api_tokens, :user_id, if_exists: true
  end
end
