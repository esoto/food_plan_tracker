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
# NO default_scope. Silent global filters mask bugs (especially in jobs and
# rake tasks where Current.user may be unset) and complicate unscoped
# reasoning.
module Tenantable
  extend ActiveSupport::Concern

  included do
    belongs_to :user, optional: true

    scope :for_user, ->(user) { user ? where(user: user) : none }

    before_validation :assign_current_user, on: :create
  end

  private

  def assign_current_user
    self.user ||= Current.user
    return if user.present?

    # Fallback for child models: derive from parent association
    self.user ||= meal&.user        if respond_to?(:meal)        && meal.present?
    self.user ||= plan&.user        if respond_to?(:plan)        && plan.present?
    self.user ||= daily_log&.user   if respond_to?(:daily_log)   && daily_log.present?
    self.user ||= supplement&.user  if respond_to?(:supplement)  && supplement.present?
    self.user ||= goal&.user        if respond_to?(:goal)        && goal.present?
  end
end
