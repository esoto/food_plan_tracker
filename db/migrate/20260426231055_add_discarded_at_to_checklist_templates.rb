class AddDiscardedAtToChecklistTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :checklist_templates, :discarded_at, :datetime
    add_index :checklist_templates, :discarded_at
  end
end
