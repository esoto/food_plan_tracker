class SupplementSchedule < ApplicationRecord
  include Tenantable

  TIME_SLOTS = { morning: 0, pre_lunch: 1, dinner: 2, pre_sleep: 3 }.freeze

  enum :time_slot, TIME_SLOTS

  belongs_to :supplement

  validates :time_slot, :position, presence: true

  # Each slot's representative wall-clock time in the app's local zone.
  # ReminderTickerJob iterates these to decide when to fire push
  # reminders; the prose `time:` field below is human-display only.
  SLOT_TIMES = {
    "morning"   => [ 7,  0 ],
    "pre_lunch" => [ 11, 45 ],
    "dinner"    => [ 19, 30 ],
    "pre_sleep" => [ 22, 0 ]
  }.freeze

  TIME_SLOT_LABELS = {
    "morning"   => { label: "Morning",    time: "7:00 AM" },
    "pre_lunch" => { label: "Pre-lunch",  time: "11:45 AM" },
    "dinner"    => { label: "Dinner",     time: "7:30 PM" },
    "pre_sleep" => { label: "Before bed", time: "10:00 PM" }
  }.freeze

  def slot_label
    TIME_SLOT_LABELS[time_slot][:label]
  end

  def slot_time
    TIME_SLOT_LABELS[time_slot][:time]
  end
end
