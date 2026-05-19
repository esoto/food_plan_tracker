class AddUserIdToPushSubscriptions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :push_subscriptions, :user_id, :bigint, if_not_exists: true
    add_index :push_subscriptions, :user_id, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :push_subscriptions, :user_id, algorithm: :concurrently, if_exists: true
    remove_column :push_subscriptions, :user_id, if_exists: true
  end
end
