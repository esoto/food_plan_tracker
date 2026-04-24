class CreateLoggedFoods < ActiveRecord::Migration[8.1]
  def change
    create_table :logged_foods do |t|
      t.references :daily_log, null: false, foreign_key: true
      t.references :food, null: false, foreign_key: true
      t.decimal :quantity_grams, precision: 7, scale: 2, null: false
      t.datetime :logged_at, null: false

      t.timestamps
    end
    add_index :logged_foods, [ :daily_log_id, :logged_at ]
  end
end
