class AddCreatedByUserToFoods < ActiveRecord::Migration[8.1]
  def change
    add_reference :foods, :created_by_user, foreign_key: { to_table: :users }, null: true
  end
end
