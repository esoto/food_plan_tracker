# Cron-style ticker that fires every minute via config/recurring.yml.
#
# On each tick we ask: "is anything due right now?"
#   - any meal on today's plan whose scheduled_time HH:MM matches now
#     and isn't completed yet → push "🍱 <Meal> time"
#   - any supplement-time-slot whose representative time matches now
#     and has uncompleted supplements → push "💊 <slot> supplements"
#
# We deliberately group supplements into a single push per slot rather
# than per-supplement: the user has 5+ pills in the morning slot, and
# 5 simultaneous notifications would be obnoxious.
class ReminderTickerJob < ApplicationJob
  queue_as :default

  # Cap the meal name in the push payload. Meals are admin/seed-managed
  # today, but defense-in-depth before that surface ever opens up — push
  # services reject payloads above ~4KB, and an emoji-bombed name would
  # waste budget on the wrong axis.
  MEAL_NAME_LIMIT = 50

  def perform(now: Time.current)
    return unless PushNotifier.configured?

    today = DailyLog.today
    return unless today&.plan # no-op if seed data isn't ready (fresh install, etc.)

    fire_meal_reminders(today, now)
    fire_supplement_reminders(today, now)
  end

  private

  def fire_meal_reminders(today, now)
    completed_ids = today.meal_completions.pluck(:meal_id).to_set

    today.plan.meals.each do |meal|
      # `scheduled_time` is a Postgres `time` column. Rails' default
      # cast wraps it in the local zone, which shifts the wall-clock
      # hour. The model convention (see Meal#time_of_day) is to read
      # via .utc.hour/.utc.min — that gives back the literal HH:MM the
      # user typed in /settings.
      next unless meal.scheduled_time.utc.hour == now.hour && meal.scheduled_time.utc.min == now.min
      next if completed_ids.include?(meal.id)

      meal_name = meal.name.to_s.truncate(MEAL_NAME_LIMIT)
      PushNotifier.broadcast(
        title: "🍱 #{meal_name} time",
        body:  "Time to log #{meal_name} (~#{meal.target_kcal} kcal).",
        url:   "/menu"
      )
    end
  end

  def fire_supplement_reminders(today, now)
    # Pluck once outside the loop — the per-slot guard means at most
    # one slot fires per tick, but doing the read up-front mirrors the
    # meal_reminders pattern and is robust if two slots ever share a
    # minute.
    taken_ids = today.supplement_completions.pluck(:supplement_id).to_set

    SupplementSchedule::SLOT_TIMES.each do |slot, (h, m)|
      next unless h == now.hour && m == now.min

      pending = supplements_in_slot(slot).reject { |id| taken_ids.include?(id) }
      next if pending.empty?

      PushNotifier.broadcast(
        title: "💊 #{slot.titleize} supplements",
        body:  "#{pending.size} #{'supplement'.pluralize(pending.size)} due now.",
        url:   "/supplements"
      )
    end
  end

  def supplements_in_slot(slot)
    SupplementSchedule.where(time_slot: slot).pluck(:supplement_id)
  end
end
