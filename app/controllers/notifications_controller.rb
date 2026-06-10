class NotificationsController < ApplicationController
  # Per-tenant: each user only sees their own subscriptions + deliveries.
  def show
    @subscriptions = Current.user.push_subscriptions.order(created_at: :desc).to_a
    @recent_deliveries = Current.user.notification_deliveries.recent(20)
    @subscription_count = @subscriptions.size
    @plan = today_log&.plan

    # Mirror the guard in UserReminderJob: don't crash the page on a
    # fresh install where the seed plans haven't run yet.
    @meal_reminders = @plan ? meal_reminders_for(@plan) : []
    @supplement_reminders = supplement_reminders
  end

  private

  def meal_reminders_for(plan)
    plan.meals.ordered.map do |meal|
      {
        meal: meal,
        enabled: ReminderPreference.enabled?(reminder_type: "meal", key: meal.name)
      }
    end
  end

  def supplement_reminders
    SupplementSchedule::SLOT_TIMES.keys.map do |slot|
      {
        slot:   slot,
        time:  SupplementSchedule::TIME_SLOT_LABELS[slot][:time],
        label: SupplementSchedule::TIME_SLOT_LABELS[slot][:label],
        enabled: ReminderPreference.enabled?(reminder_type: "supplement_slot", key: slot)
      }
    end
  end
end
