require "rails_helper"

RSpec.describe Settings::ChecklistTemplatesController, type: :request do
  before { sign_in_as }

  describe "GET /settings/habits" do
    it "lists kept templates and excludes discarded" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "Drink water", position: 0)
      create(:checklist_template, label: "Old habit", position: 1, discarded_at: 1.day.ago)

      get settings_habits_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Drink water")
      expect(response.body).not_to include("Old habit")
    end
  end

  describe "GET /settings/habits/archived" do
    it "lists only discarded templates" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "Drink water", position: 0)
      create(:checklist_template, label: "Old habit", position: 1, discarded_at: 1.day.ago)

      get archived_settings_habits_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Old habit")
      expect(response.body).not_to include("Drink water")
    end
  end

  describe "POST /settings/habits" do
    it "creates a template with auto-incremented position" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "First", position: 0)

      expect {
        post settings_habits_path, params: { checklist_template: { label: "Second" } }
      }.to change(ChecklistTemplate.kept, :count).by(1)

      expect(ChecklistTemplate.kept.find_by(label: "Second").position).to eq(1)
    end

    it "renders new on validation failure" do
      post settings_habits_path, params: { checklist_template: { label: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /settings/habits/:id" do
    it "updates label, description, icon" do
      template = create(:checklist_template, label: "Old", position: 0)
      patch settings_habit_path(template), params: {
        checklist_template: { label: "New", description: "x", icon: "💧" }
      }

      template.reload
      expect(template.label).to eq("New")
      expect(template.description).to eq("x")
      expect(template.icon).to eq("💧")
    end
  end

  describe "DELETE /settings/habits/:id" do
    it "soft-deletes and preserves completion records" do
      template = create(:checklist_template, position: 0)
      plan = create(:plan)
      log = create(:daily_log, plan: plan)
      completion = create(:checklist_completion, checklist_template: template, daily_log: log)

      expect {
        delete settings_habit_path(template)
      }.not_to change(ChecklistCompletion, :count)

      expect(template.reload.discarded_at).to be_present
      expect(completion.reload).to be_persisted
    end
  end

  describe "PATCH /settings/habits/:id/restore" do
    it "restores a discarded template at the end of the position list" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "A", position: 0)
      create(:checklist_template, label: "B", position: 1)
      restored = create(:checklist_template, label: "Old", position: 2, discarded_at: 1.day.ago)

      patch restore_settings_habit_path(restored)

      expect(restored.reload.discarded_at).to be_nil
      expect(restored.position).to eq(2)
    end
  end

  describe "PATCH /settings/habits/:id/move_up and move_down" do
    let!(:templates) do
      ChecklistTemplate.delete_all
      [
        create(:checklist_template, label: "A", position: 0),
        create(:checklist_template, label: "B", position: 1),
        create(:checklist_template, label: "C", position: 2)
      ]
    end

    it "swaps position with the previous template (move_up)" do
      patch move_up_settings_habit_path(templates[1])
      expect(templates.map { |t| t.reload.position }).to eq([ 1, 0, 2 ])
    end

    it "swaps position with the next template (move_down)" do
      patch move_down_settings_habit_path(templates[1])
      expect(templates.map { |t| t.reload.position }).to eq([ 0, 2, 1 ])
    end

    it "no-ops at the top edge" do
      patch move_up_settings_habit_path(templates[0])
      expect(templates.map { |t| t.reload.position }).to eq([ 0, 1, 2 ])
    end

    it "no-ops at the bottom edge" do
      patch move_down_settings_habit_path(templates[2])
      expect(templates.map { |t| t.reload.position }).to eq([ 0, 1, 2 ])
    end
  end
end
