class CreateChecklistCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :checklist_completions do |t|
      t.references :daily_log, null: false, foreign_key: true
      t.references :checklist_template, null: false, foreign_key: true
      t.boolean :checked, null: false, default: false

      t.timestamps
    end
    add_index :checklist_completions, [ :daily_log_id, :checklist_template_id ], unique: true, name: "idx_checklist_completions_on_log_and_template"
  end
end
