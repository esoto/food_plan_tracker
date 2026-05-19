# frozen_string_literal: true

# Tenantable provides multi-user scoping for ActiveRecord models.
#
# Design notes:
# 1. +for_user+ is the primary filter for ALL operations (reads, creates,
#    updates, destroys). +assign_current_user+ only sets the owner on create.
# 2. Always chain +for_user(user).kept+, NOT +kept.for_user(user)+ —
#    +for_user+ must come first so the tenant boundary is established before
#    any other scope is applied.
# 3. Top-level models (Plan, Goal, Supplement, ChecklistTemplate,
#    ReminderPreference) have NO fallback — they rely 100% on Current.user.
# 4. +belongs_to :user, optional: true+ is transitional. PER-553 switches to
#    required after backfill + NOT NULL.
#
# 5. Including models MUST NOT declare their own +belongs_to :user+ — the
#    concern owns the association. Re-declaring would silently override due to
#    ActiveRecord's last-declaration-wins rule.
#
# NO default_scope. Silent global filters mask bugs (especially in jobs and
# rake tasks where Current.user may be unset) and complicate unscoped
# reasoning.
module Tenantable
  extend ActiveSupport::Concern

  # Associations checked in precedence order for deriving user from a parent.
  TENANT_PARENT_ASSOCIATIONS = %i[meal plan daily_log supplement goal].freeze

  included do
    belongs_to :user, optional: true
    attr_readonly :user_id

    scope :for_user, ->(user) { user ? where(user: user) : none }

    before_validation :assign_current_user, on: :create
  end

  private

  def assign_current_user
    self.user ||= Current.user
    return if user.present?

    # Fallback for child models: derive from parent association
    Tenantable::TENANT_PARENT_ASSOCIATIONS.each do |assoc|
      next unless respond_to?(assoc) && send(assoc).present?
      self.user ||= send(assoc).user
    end
  end
end
