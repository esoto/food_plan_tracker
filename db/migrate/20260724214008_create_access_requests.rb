class CreateAccessRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :access_requests do |t|
      t.string :email_address, null: false
      t.text :message

      t.timestamps
    end

    add_index :access_requests, :email_address, unique: true
  end
end
