class NotificationsController < ApplicationController
  # Lists every PushSubscription regardless of user — single-user app.
  # If the app ever grows past one user, scope this to current_user.
  def show
    @subscriptions = PushSubscription.order(created_at: :desc)
    @recent_deliveries = NotificationDelivery.recent(20)
    @plan = today_log&.plan

    # Mirror the guard in ReminderTickerJob: don't crash the page on a
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
