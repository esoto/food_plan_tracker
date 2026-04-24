class CreateBiomarkerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :biomarker_entries do |t|
      t.references :goal, null: false, foreign_key: true
      t.date :recorded_on, null: false
      t.decimal :value, precision: 7, scale: 2, null: false

      t.timestamps
    end
    add_index :biomarker_entries, [ :goal_id, :recorded_on ]
  end
end
