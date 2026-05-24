class NotificationDelivery < ApplicationRecord
  belongs_to :user

  validates :title, :fired_at, presence: true

  scope :for_user, ->(user) { user ? where(user: user) : none }
  scope :recent, ->(limit = 20) { order(fired_at: :desc).limit(limit) }
end
