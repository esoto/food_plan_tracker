class CreateSupplementCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :supplement_completions do |t|
      t.references :daily_log, null: false, foreign_key: true
      t.references :supplement, null: false, foreign_key: true
      t.datetime :taken_at, null: false

      t.timestamps
    end
    add_index :supplement_completions, [ :daily_log_id, :supplement_id ], unique: true
  end
end
