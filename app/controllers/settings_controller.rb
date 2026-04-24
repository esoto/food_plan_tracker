class SettingsController < ApplicationController
  def show
    @plans = Plan.ordered
    @goals = Goal.all
  end
end
