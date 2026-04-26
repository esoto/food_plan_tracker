require "rails_helper"

RSpec.describe DailyLogsController, type: :request do
  let(:plan) { create(:plan) }
  let(:daily_log) { DailyLog.create!(date: Date.current, plan: plan) }

  before { sign_in_as }

  describe "PATCH /daily_logs/:id" do
    it "updates the journal note and redirects 303" do
      patch daily_log_path(daily_log),
            params: { daily_log: { notes: "Felt great after morning workout" } },
            headers: { "Referer" => root_url }
      expect(response).to have_http_status(:see_other)
      expect(daily_log.reload.notes).to eq("Felt great after morning workout")
    end

    it "accepts an empty note (clears it)" do
      daily_log.update!(notes: "old text")
      patch daily_log_path(daily_log),
            params: { daily_log: { notes: "" } },
            headers: { "Referer" => root_url }
      expect(daily_log.reload.notes).to eq("")
    end
  end
end
