class CreateMeals < ActiveRecord::Migration[8.1]
  def change
    create_table :meals do |t|
      t.references :plan, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :name, null: false
      t.time :scheduled_time, null: false
      t.integer :target_kcal, null: false
      t.decimal :target_protein_g, precision: 6, scale: 2, null: false
      t.decimal :target_carbs_g, precision: 6, scale: 2, null: false
      t.decimal :target_fat_g, precision: 6, scale: 2, null: false

      t.timestamps
    end
    add_index :meals, [ :plan_id, :position ], unique: true
  end
end
