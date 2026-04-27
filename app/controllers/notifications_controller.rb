class NotificationsController < ApplicationController
  def show
    @subscriptions = PushSubscription.order(created_at: :desc)
    @recent_deliveries = NotificationDelivery.recent(20)
    @plan = today_log.plan
    @meal_reminders = @plan.meals.ordered.map do |meal|
      {
        meal: meal,
        enabled: ReminderPreference.enabled?(reminder_type: "meal", key: meal.name)
      }
    end
    @supplement_reminders = SupplementSchedule::SLOT_TIMES.keys.map do |slot|
      {
        slot:    slot,
        time:   SupplementSchedule::TIME_SLOT_LABELS[slot][:time],
        label:  SupplementSchedule::TIME_SLOT_LABELS[slot][:label],
        enabled: ReminderPreference.enabled?(reminder_type: "supplement_slot", key: slot)
      }
    end
  end
end
