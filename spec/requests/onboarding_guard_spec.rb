require "rails_helper"

# Accounts created outside the sign-up flow (console, pre-onboarding data)
# have no plans, and DailyLog.for cannot build today's log without one.
# The ApplicationController guard self-heals by running the idempotent
# Onboarding::SeedDefaults on the first authenticated request.
RSpec.describe "Lazy onboarding guard", type: :request do
  let(:user) { User.create!(email_address: "console-made@example.com", password: "password12345") }

  before do
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end

  it "seeds default plans for a plan-less user instead of 500ing the dashboard" do
    expect(user.plans.count).to eq(0)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(user.plans.count).to eq(3)
    expect(user.plans.pluck(:slug)).to contain_exactly("exercise", "active", "rest")
  end

  it "does not touch an already-onboarded user's plans" do
    Onboarding::SeedDefaults.call(user)
    user.plans.find_by!(slug: "active").update!(target_kcal: 1800)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(user.plans.count).to eq(3)
    expect(user.plans.find_by!(slug: "active").target_kcal).to eq(1800)
  end

  it "never seeds plans for another user" do
    other = create(:user)

    get root_path

    expect(Plan.where(user: other)).to be_empty
  end
end
