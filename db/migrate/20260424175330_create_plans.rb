class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :target_kcal, null: false
      t.integer :target_protein_g, null: false
      t.integer :target_carbs_g, null: false
      t.integer :target_fat_g, null: false

      t.timestamps
    end
    add_index :plans, :slug, unique: true
  end
end
