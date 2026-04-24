class SupplementCompletion < ApplicationRecord
  belongs_to :daily_log
  belongs_to :supplement

  validates :taken_at, presence: true
  validates :supplement_id, uniqueness: { scope: :daily_log_id }
end
