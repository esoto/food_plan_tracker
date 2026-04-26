class SettingsController < ApplicationController
  def show
    @plans = Plan.ordered.includes(:meals)
    @goals = Goal.includes(:biomarker_entries)
  end
end
