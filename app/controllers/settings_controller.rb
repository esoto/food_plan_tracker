class SettingsController < ApplicationController
  def show
    @plans = Current.user.plans.ordered.includes(:meals) if food_tracking?
    @goals = Goal.for_user(Current.user).includes(:biomarker_entries)
  end
end
