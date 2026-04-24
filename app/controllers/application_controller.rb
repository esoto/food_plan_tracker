class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern

  stale_when_importmap_changes

  helper_method :today_log, :current_user, :nav_items

  private

  def today_log
    @today_log ||= DailyLog.today
  end

  def current_user
    Current.user
  end

  NAV_ITEMS = [
    { key: :today,       path: "/",            label: "Hoy",         icon: "home" },
    { key: :menu,        path: "/menu",        label: "Menú",        icon: "utensils" },
    { key: :exchanges,   path: "/exchanges",   label: "Alimentos",   icon: "shuffle" },
    { key: :supplements, path: "/supplements", label: "Suplementos", icon: "pill" },
    { key: :checklist,   path: "/checklist",   label: "Hábitos",     icon: "check" }
  ].freeze

  def nav_items
    NAV_ITEMS
  end
end
