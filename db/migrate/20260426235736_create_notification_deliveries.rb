class CreateNotificationDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_deliveries do |t|
      t.string   :title,        null: false
      t.text     :body
      t.string   :url
      t.integer  :sent_count,   null: false, default: 0
      t.integer  :pruned_count, null: false, default: 0
      t.datetime :fired_at,     null: false

      t.timestamps
    end

    # Most queries are "the most recent N" → fired_at desc.
    add_index :notification_deliveries, :fired_at
  end
end
