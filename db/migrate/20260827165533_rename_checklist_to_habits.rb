class RenameChecklistToHabits < ActiveRecord::Migration[8.1]
  def change
    rename_table :checklist_templates, :habits
    rename_table :checklist_completions, :habit_entries
    rename_column :habit_entries, :checklist_template_id, :habit_id

    # rename_table/rename_column are catalog-only; FKs (OID) and indexes
    # (attnum) survive. Rename the stale identifiers for readability.
    rename_index :habit_entries, "idx_checklist_completions_on_log_and_template",
                 "idx_habit_entries_on_log_and_habit"
    rename_index :habits, "index_checklist_templates_kept", "index_habits_kept"
  end
end
