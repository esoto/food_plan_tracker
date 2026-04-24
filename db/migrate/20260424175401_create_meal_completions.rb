class CreateMealCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_completions do |t|
      t.references :daily_log, null: false, foreign_key: true
      t.references :meal, null: false, foreign_key: true
      t.datetime :completed_at, null: false

      t.timestamps
    end
    add_index :meal_completions, [ :daily_log_id, :meal_id ], unique: true
  end
end
