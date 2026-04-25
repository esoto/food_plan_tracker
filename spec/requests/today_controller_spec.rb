require "rails_helper"

RSpec.describe TodayController, type: :request do
  before do
    create(:plan, slug: "exercise", name: "Exercise day")
    create(:plan, slug: "active",   name: "Active day")
    create(:plan, slug: "rest",     name: "Rest day")
    sign_in_as
  end

  describe "GET /" do
    it "renders only goals that have at least one biomarker reading" do
      tracked   = create(:goal, :weight, :with_measurement, measurement_value: 90.0)
      untracked = create(:goal)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(tracked.display_name)
      expect(response.body).not_to include(untracked.display_name)
    end

    it "renders the '+ Log a biomarker' CTA when at least one goal has no readings" do
      create(:goal, :weight, :with_measurement, measurement_value: 90.0)
      create(:goal)

      get root_path

      expect(response.body).to include("+ Log a biomarker")
      expect(response.body).to include("1 untracked")
    end

    it "hides the CTA when every goal has at least one reading" do
      create(:goal, :weight,   :with_measurement, measurement_value: 90.0)
      create(:goal, :preserve, :with_measurement, measurement_value: 67.0)

      get root_path

      expect(response.body).not_to include("+ Log a biomarker")
    end
  end
end
