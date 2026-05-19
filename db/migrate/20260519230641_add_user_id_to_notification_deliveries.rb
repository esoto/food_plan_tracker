class AddUserIdToNotificationDeliveries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  # NOTE: PER-553 backfill must run after push_subscriptions.user_id and reminder_preferences.user_id are populated.

  def up
    add_column :notification_deliveries, :user_id, :bigint, if_not_exists: true
    add_index :notification_deliveries, :user_id, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :notification_deliveries, :user_id, algorithm: :concurrently, if_exists: true
    remove_column :notification_deliveries, :user_id, if_exists: true
  end
end
