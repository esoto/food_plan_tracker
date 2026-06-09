require "rails_helper"

RSpec.describe ChecklistCompletionsController, type: :request do
  let(:user) { create(:user) }
  let(:plan) { create(:plan, user: user) }
  let(:template) { create(:checklist_template, user: user, label: "Walk", position: 0) }
  let(:daily_log) { create(:daily_log, user: user, plan: plan, date: Date.current) }

  before { sign_in_as(user) }

  describe "PATCH /checklist_completions/:id" do
    it "checks the user's own template for the requested day" do
      patch checklist_completion_path(template),
            params: { daily_log_id: daily_log.id, checked: "1" }

      completion = daily_log.checklist_completions.find_by(checklist_template: template)
      expect(completion.checked).to be true
      expect(response).to have_http_status(:redirect)
    end

    it "unchecks the template when checked: 0 is passed" do
      create(:checklist_completion, daily_log: daily_log, checklist_template: template, checked: true)

      patch checklist_completion_path(template),
            params: { daily_log_id: daily_log.id, checked: "0" }

      expect(daily_log.checklist_completions.find_by(checklist_template: template).checked).to be false
    end

    it "POSITIVE CONTROL: PATCH on the user's own past-day log still works" do
      past_plan = create(:plan, slug: "active-past", user: user, name: "Past plan")
      past_log  = create(:daily_log, user: user, plan: past_plan, date: 2.days.ago.to_date)
      create(:checklist_completion, daily_log: past_log, checklist_template: template, checked: false)

      patch checklist_completion_path(template),
            params: { daily_log_id: past_log.id, checked: "1" }

      expect(past_log.checklist_completions.find_by(checklist_template: template).checked).to be true
    end

    it "returns 404 and preserves untouched state when template_id belongs to another user" do
      user_b = create(:user)
      _b_template = create(:checklist_template, user: user_b, label: "Other's Walk", position: 0)

      patch checklist_completion_path(_b_template),
            params: { daily_log_id: daily_log.id, checked: "1" }

      expect(response).to have_http_status(:not_found)
      # The user's own template should NOT have been toggled.
      expect(daily_log.checklist_completions.find_by(checklist_template: template)).to be_nil
    end

    it "returns 404 when daily_log_id belongs to another user" do
      user_b = create(:user)
      plan_b = create(:plan, user: user_b)
      _log_b = create(:daily_log, user: user_b, plan: plan_b, date: Date.current)

      patch checklist_completion_path(template),
            params: { daily_log_id: _log_b.id, checked: "1" }

      expect(response).to have_http_status(:not_found)
      # No completion should be written to either log.
      expect(_log_b.checklist_completions.count).to eq(0)
      expect(daily_log.checklist_completions.count).to eq(0)
    end
  end
end
