class ConvertDiscardedAtIndexesToPartial < ActiveRecord::Migration[8.1]
  # Replace the plain b-tree on `discarded_at` with a partial index that only
  # covers kept rows. Every hot query (`/supplements`, `/checklist`,
  # adherence calc, settings indexes) filters `WHERE discarded_at IS NULL`;
  # the discarded scope is only hit by the two archived-list pages. A partial
  # index is smaller, matches the planner's needs better, and is the canonical
  # soft-delete pattern on PostgreSQL.
  def change
    remove_index :supplements, :discarded_at
    add_index    :supplements, :discarded_at,
                 where: "discarded_at IS NULL",
                 name:  "index_supplements_kept"

    remove_index :checklist_templates, :discarded_at
    add_index    :checklist_templates, :discarded_at,
                 where: "discarded_at IS NULL",
                 name:  "index_checklist_templates_kept"
  end
end
