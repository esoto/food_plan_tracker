class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern

  stale_when_importmap_changes

  # Registration runs Onboarding::SeedDefaults, but accounts created any
  # other way (console, seeds-interrupted, pre-onboarding data) have no
  # plans — and DailyLog.for cannot create a log without one, which 500s
  # the dashboard. Self-heal lazily: the service is idempotent and
  # race-safe, and the exists? check costs one indexed query per request.
  # Keyed on Current.session (already resumed by require_authentication)
  # rather than authenticated? so unauthenticated-allowed actions don't
  # trigger an extra session lookup.
  before_action :ensure_onboarding_defaults, if: -> { Current.session }

  helper_method :today_log, :current_user, :nav_items, :fibrotina_due?, :fibrotina_supplement, :food_tracking?

  private

  def ensure_onboarding_defaults
    Onboarding::SeedDefaults.call(Current.user) unless Current.user.plans.exists?
  end

  def today_log
    @today_log ||= DailyLog.today(Current.user)
  end

  # Resolve which DailyLog a write should target. When a form passes an
  # explicit daily_log_id (the past-day editor does this) we trust it;
  # otherwise default to today.
  def daily_log_from_params
    if params[:daily_log_id].present?
      Current.user.daily_logs.find(params[:daily_log_id])
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

  def fibrotina_supplement
    @fibrotina_supplement ||= Supplement.for_user(Current.user).kept.find_by("name ILIKE ?", "Fibrotina%")
  end

  def fibrotina_due?
    return false unless authenticated?

    return false unless fibrotina_supplement

    # If already taken today, never show the banner (covers both real window
    # and dev preview).
    return false if today_log.supplement_completions.exists?(supplement: fibrotina_supplement)

    # Dev-only preview override: append ?preview_fibrotina=1 to any URL.
    return true if Rails.env.development? && params[:preview_fibrotina] == "1"

    now = Time.current
    FIBROTINA_WINDOW.cover?(now.hour * 60 + now.min)
  end

  NAV_ITEMS = [
    { key: :today,       path: "/",            label: "Today",      icon: "home" },
    { key: :menu,        path: "/menu",        label: "Menu",       icon: "utensils",   food: true },
    { key: :exchanges,   path: "/exchanges",   label: "Foods",      icon: "shuffle",    food: true },
    { key: :supplements, path: "/supplements", label: "Supplements", icon: "pill" },
    { key: :habits,      path: "/habits",      label: "Habits",     icon: "check" }
  ].freeze

  # Shown only when food tracking is off, inserted between Habits and
  # Supplements so the food-off order reads Today · Habits · Progress ·
  # Supplements.
  PROGRESS_NAV_ITEM = { key: :progress, path: "/progress", label: "Progress", icon: "chart" }.freeze

  def food_tracking?
    Current.user&.food_tracking_enabled?
  end

  def nav_items
    if food_tracking?
      NAV_ITEMS
    else
      without_food = NAV_ITEMS.reject { |item| item[:food] }
      today = without_food.find { |item| item[:key] == :today }
      habits = without_food.find { |item| item[:key] == :habits }
      supplements = without_food.find { |item| item[:key] == :supplements }
      [today, habits, PROGRESS_NAV_ITEM, supplements]
    end
  end
end
