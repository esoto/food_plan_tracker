class NotificationDelivery < ApplicationRecord
  validates :title, :fired_at, presence: true

  scope :recent, ->(limit = 20) { order(fired_at: :desc).limit(limit) }
end
