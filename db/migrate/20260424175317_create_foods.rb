class CreateFoods < ActiveRecord::Migration[8.1]
  def change
    create_table :foods do |t|
      t.string :name, null: false
      t.integer :category, null: false
      t.decimal :serving_grams, precision: 7, scale: 2, null: false
      t.integer :kcal, null: false
      t.decimal :protein_g, precision: 6, scale: 2, null: false, default: 0
      t.decimal :carbs_g, precision: 6, scale: 2, null: false, default: 0
      t.decimal :fat_g, precision: 6, scale: 2, null: false, default: 0
      t.string :notes

      t.timestamps
    end
    add_index :foods, [ :category, :name ]
  end
end
