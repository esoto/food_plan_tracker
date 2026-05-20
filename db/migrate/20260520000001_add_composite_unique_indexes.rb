class AddCompositeUniqueIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :plans, [:user_id, :slug], unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :daily_logs, [:user_id, :date], unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :goals, [:user_id, :metric], unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :api_tokens, [:user_id, :name], unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :api_tokens, [:user_id, :token_digest], unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :reminder_preferences, [:user_id, :reminder_type, :key], unique: true, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :plans, [:user_id, :slug], algorithm: :concurrently, if_exists: true
    remove_index :daily_logs, [:user_id, :date], algorithm: :concurrently, if_exists: true
    remove_index :goals, [:user_id, :metric], algorithm: :concurrently, if_exists: true
    remove_index :api_tokens, [:user_id, :name], algorithm: :concurrently, if_exists: true
    remove_index :api_tokens, [:user_id, :token_digest], algorithm: :concurrently, if_exists: true
    remove_index :reminder_preferences, [:user_id, :reminder_type, :key], algorithm: :concurrently, if_exists: true
  end
end
