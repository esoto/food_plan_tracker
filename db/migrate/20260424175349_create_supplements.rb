class CreateSupplements < ActiveRecord::Migration[8.1]
  def change
    create_table :supplements do |t|
      t.string :name, null: false
      t.string :dose, null: false
      t.string :notes
      t.boolean :critical, null: false, default: false
      t.string :contraindications

      t.timestamps
    end
  end
end
