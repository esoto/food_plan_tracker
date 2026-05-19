class AddUserIdToChecklistTemplates < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :checklist_templates, :user_id, :bigint
    add_index :checklist_templates, :user_id, algorithm: :concurrently
  end

  def down
    remove_index :checklist_templates, :user_id, algorithm: :concurrently
    remove_column :checklist_templates, :user_id
  end
end
