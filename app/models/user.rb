class User < ApplicationRecord
  class LastAdminError < StandardError; end

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :plans, dependent: :destroy
  has_many :meals, dependent: :destroy
  has_many :daily_logs, dependent: :destroy
  has_many :supplements, dependent: :destroy
  has_many :supplement_schedules, dependent: :destroy
  has_many :goals, dependent: :destroy
  has_many :biomarker_entries, dependent: :destroy
  has_many :checklist_templates, dependent: :destroy
  has_many :logged_foods, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :reminder_preferences, dependent: :destroy
  has_many :notification_deliveries, dependent: :destroy
  has_many :meal_items, dependent: :destroy
  has_many :oauth_access_grants, class_name: "Doorkeeper::AccessGrant", foreign_key: :resource_owner_id, dependent: :delete_all
  has_many :oauth_access_tokens, class_name: "Doorkeeper::AccessToken", foreign_key: :resource_owner_id, dependent: :delete_all
  # Nullified foods read as seeded; the seeds prune guard handles true orphans.
  has_many :created_foods, class_name: "Food", foreign_key: :created_by_user_id, dependent: :nullify

  enum :role, { member: 0, admin: 1 }, default: :member

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 12 }, allow_nil: true

  # Binding the token to the password salt means an accepted invite (which sets
  # a password) invalidates any outstanding invitation tokens — same trick Rails
  # uses for its built-in password_reset purpose.
  generates_token_for :invitation, expires_in: 3.days do
    password_salt&.last(10)
  end

  scope :active, -> { where(deactivated_at: nil) }

  scope :with_admin_insights, -> {
    select(<<~SQL.squish)
      users.*,
      (SELECT COUNT(*) FROM daily_logs WHERE daily_logs.user_id = users.id) AS days_logged_count,
      (SELECT COUNT(*) FROM api_tokens WHERE api_tokens.user_id = users.id) AS api_tokens_count,
      (SELECT COUNT(*) FROM push_subscriptions WHERE push_subscriptions.user_id = users.id) AS push_subscriptions_count,
      GREATEST(
        (SELECT MAX(sessions.updated_at) FROM sessions WHERE sessions.user_id = users.id),
        (SELECT MAX(api_tokens.last_used_at) FROM api_tokens WHERE api_tokens.user_id = users.id)
      ) AS last_activity_at
    SQL
      .order(:created_at)
  }

  before_destroy :guard_last_active_admin

  def active? = deactivated_at.nil?

  def deactivated? = deactivated_at.present?

  def last_active_admin?
    admin? && active? && self.class.active.admin.count == 1
  end

  def deactivate!
    raise LastAdminError if last_active_admin?

    transaction do
      update!(deactivated_at: Time.current)
      sessions.destroy_all
    end
  end

  def reactivate!
    update!(deactivated_at: nil)
  end

  def promote!
    update!(role: :admin)
  end

  def demote!
    raise LastAdminError if last_active_admin?

    update!(role: :member)
  end

  private

  def guard_last_active_admin
    raise LastAdminError if last_active_admin?
  end
end
