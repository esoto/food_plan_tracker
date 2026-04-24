class CreateMealItems < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_items do |t|
      t.references :meal, null: false, foreign_key: true
      t.references :food, null: false, foreign_key: true
      t.decimal :quantity_grams, precision: 7, scale: 2, null: false
      t.integer :display_order, null: false, default: 0

      t.timestamps
    end
  end
end
