require "rails_helper"

# These confirm the existing user-facing pages and tracking endpoints
# transparently filter out anything that's been soft-deleted.
RSpec.describe "Discarded supplement and habit visibility", type: :request do
  before do
    create(:plan, slug: "exercise", name: "Exercise day")
    sign_in_as
  end

  describe "GET /supplements" do
    it "does not render schedules whose supplement is discarded" do
      kept = create(:supplement, name: "Magnesium")
      discarded = create(:supplement, name: "OldStack", discarded_at: 1.day.ago)
      kept.supplement_schedules.create!(time_slot: "morning", position: 0)
      discarded.supplement_schedules.create!(time_slot: "morning", position: 1)

      get supplements_path

      expect(response.body).to include("Magnesium")
      expect(response.body).not_to include("OldStack")
    end
  end

  describe "POST /supplement_completions" do
    it "404s for a discarded supplement" do
      sup = create(:supplement, discarded_at: 1.day.ago)

      post supplement_completions_path, params: { supplement_id: sup.id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /checklist" do
    it "does not list discarded templates" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "Drink water", position: 0)
      create(:checklist_template, label: "OldHabit", position: 1, discarded_at: 1.day.ago)

      get checklist_path

      expect(response.body).to include("Drink water")
      expect(response.body).not_to include("OldHabit")
    end
  end

  describe "PATCH /checklist_completions/:id" do
    it "404s when the underlying template is discarded" do
      template = create(:checklist_template, position: 0, discarded_at: 1.day.ago)
      plan = create(:plan)
      log = create(:daily_log, plan: plan)

      patch checklist_completion_path(template), params: { daily_log_id: log.id, checked: "1" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
