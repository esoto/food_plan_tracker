class AddUserIdToMeals < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  # NOTE: PER-553 backfill must run after plans.user_id is populated.

  def up
    add_column :meals, :user_id, :bigint, if_not_exists: true
    add_index :meals, :user_id, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :meals, :user_id, algorithm: :concurrently, if_exists: true
    remove_column :meals, :user_id, if_exists: true
  end
end
