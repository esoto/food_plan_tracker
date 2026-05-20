class NotificationDelivery < ApplicationRecord
  belongs_to :user

  validates :title, :fired_at, presence: true

  scope :recent, ->(limit = 20) { order(fired_at: :desc).limit(limit) }
end
