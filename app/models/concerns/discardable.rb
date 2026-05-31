module Discardable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(discarded_at: nil) }
    scope :discarded, -> { where.not(discarded_at: nil) }

    # Records that were active on the given date — i.e. either still kept,
    # or discarded after the day ended. Use this for historical adherence
    # denominators so archiving a record doesn't retroactively shift past
    # percentages.
    #
    # NOT user-scoped on its own. Callers MUST chain it after for_user:
    #   Model.for_user(user).kept_on(date)
    scope :kept_on, ->(date) {
      where("discarded_at IS NULL OR discarded_at > ?", date.end_of_day)
    }
  end

  def discard!
    update!(discarded_at: Time.current) unless discarded?
  end

  def restore!
    update!(discarded_at: nil) if discarded?
  end

  def discarded?
    discarded_at.present?
  end

  def kept?
    !discarded?
  end
end
