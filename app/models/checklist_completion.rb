class ChecklistCompletion < ApplicationRecord
  belongs_to :daily_log
  belongs_to :checklist_template

  validates :checklist_template_id, uniqueness: { scope: :daily_log_id }
end
