require "rails_helper"

RSpec.describe "ExchangesController target_log scoping", type: :request do
  let!(:plan) { seed_plan(slug: "active") }
  let!(:food) { seed_food(name: "Greek yogurt 0%", category: "protein") }

  before { sign_in_as(create(:user, password: "password12345", food_tracking_enabled: true)) }

  it "renders an info banner when daily_log_id refers to a past day" do
    past = DailyLog.create!(date: Date.current - 5, plan: plan)

    get exchanges_path(daily_log_id: past.id)

    expect(response.body).to include("Logging to")
    expect(response.body).to include(past.date.strftime("%a, %b %-d"))
  end

  it "embeds daily_log_id as a hidden field in each food row form" do
    past = DailyLog.create!(date: Date.current - 1, plan: plan)

    get exchanges_path(daily_log_id: past.id)

    expect(response.body).to match(/value="#{past.id}"\s+type="hidden"\s+name="daily_log_id"/)
  end

  it "hides the banner when no daily_log_id is given" do
    get exchanges_path

    expect(response.body).not_to include("Logging to")
  end
end
