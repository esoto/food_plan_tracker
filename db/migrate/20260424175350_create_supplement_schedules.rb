class CreateSupplementSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :supplement_schedules do |t|
      t.references :supplement, null: false, foreign_key: true
      t.integer :time_slot, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :supplement_schedules, [ :time_slot, :position ]
  end
end
