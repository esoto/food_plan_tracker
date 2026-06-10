# Evaluates and fires due reminders for a SINGLE user. Enqueued once per
# user per tick by ReminderTickerJob so that one user's failure (a push
# service 5xx, a missing record) is isolated and retried independently.
#
# Establishes per-request user context via Current.set so that the
# top-level scoped models (ReminderPreference, DailyLog, SupplementSchedule)
# resolve Current.user inside the block — jobs otherwise run with
# Current.user == nil.
class UserReminderJob < ApplicationJob
  queue_as :default

  # A vanished user (deleted between enqueue and run) is a no-op, not a
  # failure worth retrying.
  discard_on ActiveJob::DeserializationError

  # Cap the meal name in the push payload. Push services reject payloads
  # above ~4KB; defense-in-depth before the meal-name surface ever opens.
  MEAL_NAME_LIMIT = 50

  def perform(user_id, now: Time.current)
    return unless PushNotifier.configured?

    user = User.find_by(id: user_id)
    return unless user

    Current.set(user: user) do
      today = DailyLog.for_user(user).find_by(date: Date.current)
      return unless today&.plan # no-op until this user's plan/seed exists

      fire_meal_reminders(user, today, now)
      fire_supplement_reminders(user, today, now)
    end
  end

  private

  def fire_meal_reminders(user, today, now)
    completed_ids = today.meal_completions.pluck(:meal_id).to_set

    today.plan.meals.each do |meal|
      # `scheduled_time` is a Postgres `time` column read via .utc.hour/min
      # so it returns the literal HH:MM the user typed (see Meal#time_of_day).
      next unless meal.scheduled_time.utc.hour == now.hour && meal.scheduled_time.utc.min == now.min
      next if completed_ids.include?(meal.id)
      next unless ReminderPreference.enabled?(reminder_type: "meal", key: meal.name, user: user)

      meal_name = meal.name.to_s.truncate(MEAL_NAME_LIMIT)
      PushNotifier.broadcast(
        title: "🍱 #{meal_name} time",
        body:  "Time to log #{meal_name} (~#{meal.target_kcal} kcal).",
        url:   "/menu",
        user:  user
      )
    end
  end

  def fire_supplement_reminders(user, today, now)
    # Pluck once outside the loop — the per-slot guard means at most
    # one slot fires per tick, but doing the read up-front mirrors the
    # meal_reminders pattern and is robust if two slots ever share a
    # minute.
    taken_ids = today.supplement_completions.pluck(:supplement_id).to_set

    SupplementSchedule::SLOT_TIMES.each do |slot, (h, m)|
      next unless h == now.hour && m == now.min
      next unless ReminderPreference.enabled?(reminder_type: "supplement_slot", key: slot, user: user)

      pending = supplements_in_slot(user, slot).reject { |id| taken_ids.include?(id) }
      next if pending.empty?

      PushNotifier.broadcast(
        title: "💊 #{slot.titleize} supplements",
        body:  "#{pending.size} #{'supplement'.pluralize(pending.size)} due now.",
        url:   "/supplements",
        user:  user
      )
    end
  end

  def supplements_in_slot(user, slot)
    SupplementSchedule.for_user(user).where(time_slot: slot).pluck(:supplement_id)
  end
end
