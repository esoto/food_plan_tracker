# Per-minute dispatcher fired by config/recurring.yml. It does no work
# itself: for each user it enqueues a UserReminderJob so that a single
# user's failure (push 5xx, missing record) is isolated and retried
# independently rather than aborting the whole tick.
#
# `now` is captured ONCE here and forwarded to every child so all users
# in a tick are evaluated against the same wall-clock minute, regardless
# of when each child actually runs.
class ReminderTickerJob < ApplicationJob
  queue_as :default

  # The dispatcher must NOT retry: re-running it would re-enqueue a child
  # for every user and double-fire that minute's pushes. Discard on
  # deserialization issues; let nothing here trigger a retry.
  discard_on ActiveJob::DeserializationError

  def perform(now: Time.current)
    return unless PushNotifier.configured?

    User.active.find_each do |user|
      UserReminderJob.perform_later(user.id, now: now)
    end
  end
end
