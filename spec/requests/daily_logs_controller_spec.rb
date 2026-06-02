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

  describe "cross-tenant isolation" do
    it "PATCH on another user's daily_log returns 404" do
      user_a = create(:user, password: "password")
      sign_in_as(user_a)
      other  = create(:user)
      plan_b = create(:plan, user: other)
      log_b  = create(:daily_log, user: other, plan: plan_b, notes: "private")

      patch daily_log_path(log_b), params: { daily_log: { notes: "hijacked" } }

      expect(response).to have_http_status(:not_found)
      expect(log_b.reload.notes).to eq("private")
    end

    it "rejects a plan_id belonging to another user" do
      user_a = create(:user, password: "password")
      sign_in_as(user_a)
      plan_a = create(:plan, slug: "active", user: user_a)
      log_a  = create(:daily_log, user: user_a, plan: plan_a)
      foreign_plan = create(:plan, user: create(:user))

      patch daily_log_path(log_a), params: { daily_log: { plan_id: foreign_plan.id } }

      expect(response).to have_http_status(:not_found)
      expect(log_a.reload.plan_id).to eq(plan_a.id)
    end
  end
end
