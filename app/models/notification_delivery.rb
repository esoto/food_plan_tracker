class NotificationDelivery < ApplicationRecord
  validates :title, :fired_at, presence: true

  scope :recent, ->(limit = 50) { order(fired_at: :desc).limit(limit) }
end
