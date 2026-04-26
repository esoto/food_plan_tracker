class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern

  stale_when_importmap_changes

  helper_method :today_log, :current_user, :nav_items, :fibrotina_due?

  private

  def today_log
    @today_log ||= DailyLog.today
  end

  # Resolve which DailyLog a write should target. When a form passes an
  # explicit daily_log_id (the past-day editor does this) we trust it;
  # otherwise default to today.
  def daily_log_from_params
    if params[:daily_log_id].present?
      DailyLog.find(params[:daily_log_id])
    else
      today_log
    end
  end

  def current_user
    Current.user
  end

  # Remind to take Fibrotina between 6:45 PM and 8:45 PM if it hasn't been
  # marked as taken today.
  FIBROTINA_WINDOW = (18 * 60 + 45)..(20 * 60 + 45) # 6:45 PM – 8:45 PM

  def fibrotina_due?
    return false unless authenticated?

    fibrotina = Supplement.find_by("name ILIKE ?", "Fibrotina%")
    return false unless fibrotina

    # If already taken today, never show the banner (covers both real window
    # and dev preview).
    return false if today_log.supplement_completions.exists?(supplement: fibrotina)

    # Dev-only preview override: append ?preview_fibrotina=1 to any URL.
    return true if Rails.env.development? && params[:preview_fibrotina] == "1"

    now = Time.current
    FIBROTINA_WINDOW.cover?(now.hour * 60 + now.min)
  end

  NAV_ITEMS = [
    { key: :today,       path: "/",            label: "Today",      icon: "home" },
    { key: :menu,        path: "/menu",        label: "Menu",       icon: "utensils" },
    { key: :exchanges,   path: "/exchanges",   label: "Foods",      icon: "shuffle" },
    { key: :supplements, path: "/supplements", label: "Supplements", icon: "pill" },
    { key: :checklist,   path: "/checklist",   label: "Habits",     icon: "check" }
  ].freeze

  def nav_items
    NAV_ITEMS
  end
end
