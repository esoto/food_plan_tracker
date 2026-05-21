require "rails_helper"

RSpec.describe BiomarkerEntriesController, type: :request do
  let(:user) { create(:user, password: "password") }
  let(:plan) { seed_plan(slug: "active") }
  let!(:weight_goal) do
    Goal.find_or_create_by!(metric: 0, user: user) do |g|
      g.starting_value = 90; g.target_value = 87; g.unit = "kg"
      g.direction = "down"; g.display_name = "Weight"
    end
  end
  let!(:hdl_goal) do
    Goal.find_or_create_by!(metric: 2, user: user) do |g|
      g.starting_value = 39; g.target_value = 45; g.unit = "mg/dL"
      g.direction = "up"; g.display_name = "HDL"
    end
  end

  before do
    sign_in_as(user)
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
    plan
  end

  describe "GET /biomarker_entries/new" do
    it "renders the bulk form with all goals" do
      get new_biomarker_entry_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Log biomarkers", "Weight", "HDL")
    end
  end

  describe "POST /biomarker_entries/bulk" do
    it "creates entries for non-blank values, skips blanks, and syncs today's weight" do
      DailyLog.today
      expect {
        post bulk_biomarker_entries_path,
             params: { recorded_on: Date.current.iso8601,
                       entries: { weight_goal.id.to_s => "86.4", hdl_goal.id.to_s => "" } }
      }.to change(BiomarkerEntry, :count).by(1)

      expect(response).to redirect_to(progress_path)
      expect(BiomarkerEntry.last.value.to_f).to eq(86.4)
      expect(DailyLog.today.weight_kg.to_f).to eq(86.4)
    end

    it "creates multiple entries in one go" do
      expect {
        post bulk_biomarker_entries_path,
             params: { recorded_on: Date.current.iso8601,
                       entries: { weight_goal.id.to_s => "86.5", hdl_goal.id.to_s => "42" } }
      }.to change(BiomarkerEntry, :count).by(2)

      expect(flash[:notice]).to match(/2 readings/)
    end

    it "alerts when nothing is filled in" do
      post bulk_biomarker_entries_path,
           params: { recorded_on: Date.current.iso8601,
                     entries: { weight_goal.id.to_s => "", hdl_goal.id.to_s => "" } }

      expect(response).to redirect_to(new_biomarker_entry_path)
      expect(flash[:alert]).to match(/at least one/)
    end
  end
end
