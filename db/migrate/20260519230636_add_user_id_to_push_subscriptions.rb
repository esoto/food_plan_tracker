class AddUserIdToPushSubscriptions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :push_subscriptions, :user_id, :bigint
    add_index :push_subscriptions, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :push_subscriptions, :user_id, algorithm: :concurrently
    remove_column :push_subscriptions, :user_id
  end
end
