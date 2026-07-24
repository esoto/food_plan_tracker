class AddRoleAndDeactivatedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :integer, default: 0, null: false
    add_column :users, :deactivated_at, :datetime

    admin_email = ENV.fetch("ADMIN_EMAIL", "esoto074@gmail.com").strip.downcase
    quoted = connection.quote(admin_email)

    execute(<<~SQL.squish)
      UPDATE users SET role = 1
      WHERE id = COALESCE(
        (SELECT id FROM users WHERE email_address = #{quoted}),
        (SELECT id FROM users ORDER BY id ASC LIMIT 1)
      )
    SQL
  end

  def down
    remove_column :users, :role
    remove_column :users, :deactivated_at
  end
end
