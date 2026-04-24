class CreateChecklistTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :checklist_templates do |t|
      t.string :label, null: false
      t.string :description
      t.string :icon
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :checklist_templates, :position
  end
end
