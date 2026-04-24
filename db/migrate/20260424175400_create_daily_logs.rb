class CreateDailyLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_logs do |t|
      t.date :date, null: false
      t.references :plan, null: false, foreign_key: true
      t.decimal :weight_kg, precision: 6, scale: 2
      t.text :notes

      t.timestamps
    end
    add_index :daily_logs, :date, unique: true
  end
end
