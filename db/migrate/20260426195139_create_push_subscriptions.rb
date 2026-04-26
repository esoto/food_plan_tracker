class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      # Endpoint URLs from FCM/APNs run ~200-400 chars; use text to be
      # safe and avoid hitting btree's 8KB index-tuple limit on edge cases.
      t.text   :endpoint,   null: false
      t.string :p256dh_key, null: false
      t.string :auth_key,   null: false
      t.string :user_agent

      t.timestamps
    end

    # Endpoint is the natural unique key — re-subscribing the same browser
    # yields the same URL. md5() index keeps the unique constraint within
    # the index size limit no matter how long the endpoint gets.
    add_index :push_subscriptions, "md5(endpoint)", unique: true, name: "index_push_subscriptions_on_endpoint_md5"
  end
end
