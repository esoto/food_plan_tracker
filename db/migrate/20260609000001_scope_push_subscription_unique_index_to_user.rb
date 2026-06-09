class ScopePushSubscriptionUniqueIndexToUser < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :push_subscriptions, "user_id, md5(endpoint)",
              name: "index_push_subscriptions_on_user_and_endpoint_md5",
              unique: true, algorithm: :concurrently, if_not_exists: true
    remove_index :push_subscriptions, name: "index_push_subscriptions_on_endpoint_md5", algorithm: :concurrently, if_exists: true
  end

  def down
    # Rollback is best-effort — it fails if any endpoint is shared across users
    # (allowed under the composite index), and a failed CREATE UNIQUE INDEX
    # CONCURRENTLY leaves an INVALID index that must be dropped manually before retrying.
    remove_index :push_subscriptions, name: "index_push_subscriptions_on_user_and_endpoint_md5", algorithm: :concurrently, if_exists: true
    add_index :push_subscriptions, "md5(endpoint)",
              name: "index_push_subscriptions_on_endpoint_md5",
              unique: true, algorithm: :concurrently, if_not_exists: true
  end
end
