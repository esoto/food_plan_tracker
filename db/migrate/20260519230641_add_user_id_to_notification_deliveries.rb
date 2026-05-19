class AddUserIdToNotificationDeliveries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :notification_deliveries, :user_id, :bigint
    add_index :notification_deliveries, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :notification_deliveries, :user_id, algorithm: :concurrently
    remove_column :notification_deliveries, :user_id
  end
end
