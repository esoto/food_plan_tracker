class RemoveGlobalUniqueIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :plans, :slug, algorithm: :concurrently, if_exists: true
    remove_index :daily_logs, :date, algorithm: :concurrently, if_exists: true
    remove_index :goals, :metric, algorithm: :concurrently, if_exists: true
    remove_index :api_tokens, :name, algorithm: :concurrently, if_exists: true
    remove_index :api_tokens, :token_digest, algorithm: :concurrently, if_exists: true
    remove_index :reminder_preferences, [:reminder_type, :key], algorithm: :concurrently, if_exists: true
  end

  def down
    add_index :plans, :slug, unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :daily_logs, :date, unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :goals, :metric, unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :api_tokens, :name, unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :api_tokens, :token_digest, unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :reminder_preferences, [:reminder_type, :key], unique: true, algorithm: :concurrently, if_not_exists: true
  end
end
