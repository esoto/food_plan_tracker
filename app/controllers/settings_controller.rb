class SettingsController < ApplicationController
  def show
    @plans = Plan.ordered
    @goals = Goal.includes(:biomarker_entries)
  end
end
