class ScopePushSubscriptionUniqueIndexToUser < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :push_subscriptions, name: "index_push_subscriptions_on_endpoint_md5", algorithm: :concurrently, if_exists: true
    add_index :push_subscriptions, "user_id, md5(endpoint)",
              name: "index_push_subscriptions_on_user_and_endpoint_md5",
              unique: true, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :push_subscriptions, name: "index_push_subscriptions_on_user_and_endpoint_md5", algorithm: :concurrently, if_exists: true
    add_index :push_subscriptions, "md5(endpoint)",
              name: "index_push_subscriptions_on_endpoint_md5",
              unique: true, algorithm: :concurrently, if_not_exists: true
  end
end
