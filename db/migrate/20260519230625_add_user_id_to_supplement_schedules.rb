class AddUserIdToSupplementSchedules < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :supplement_schedules, :user_id, :bigint
    add_index :supplement_schedules, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :supplement_schedules, :user_id, algorithm: :concurrently
    remove_column :supplement_schedules, :user_id
  end
end
