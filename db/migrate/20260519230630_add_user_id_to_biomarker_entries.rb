class AddUserIdToBiomarkerEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :biomarker_entries, :user_id, :bigint, if_not_exists: true
    add_index :biomarker_entries, :user_id, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :biomarker_entries, :user_id, algorithm: :concurrently, if_exists: true
    remove_column :biomarker_entries, :user_id, if_exists: true
  end
end
