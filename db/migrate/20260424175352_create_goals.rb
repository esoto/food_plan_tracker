class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :goals do |t|
      t.integer :metric, null: false
      t.decimal :starting_value, precision: 7, scale: 2, null: false
      t.decimal :target_value, precision: 7, scale: 2, null: false
      t.string :unit, null: false
      t.integer :direction, null: false
      t.string :display_name, null: false

      t.timestamps
    end
    add_index :goals, :metric, unique: true
  end
end
