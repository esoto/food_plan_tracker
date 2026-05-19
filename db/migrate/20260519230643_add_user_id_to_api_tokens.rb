class AddUserIdToApiTokens < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :api_tokens, :user_id, :bigint
    add_index :api_tokens, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :api_tokens, :user_id, algorithm: :concurrently
    remove_column :api_tokens, :user_id
  end
end
