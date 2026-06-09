require "rails_helper"

RSpec.describe Settings::ChecklistTemplatesController, type: :request do
  before { sign_in_as }

  describe "GET /settings/habits" do
    it "lists kept templates and excludes discarded" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "Drink water", position: 0, user: Current.user)
      create(:checklist_template, label: "Old habit", position: 1, discarded_at: 1.day.ago, user: Current.user)

      get settings_habits_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Drink water")
      expect(response.body).not_to include("Old habit")
    end
  end

  describe "GET /settings/habits/archived" do
    it "lists only discarded templates" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "Drink water", position: 0, user: Current.user)
      create(:checklist_template, label: "Old habit", position: 1, discarded_at: 1.day.ago, user: Current.user)

      get archived_settings_habits_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Old habit")
      expect(response.body).not_to include("Drink water")
    end
  end

  describe "POST /settings/habits" do
    it "creates a template with auto-incremented position" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "First", position: 0, user: Current.user)

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
      template = create(:checklist_template, label: "Old", position: 0, user: Current.user)
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
      template = create(:checklist_template, position: 0, user: Current.user)
      plan = create(:plan, user: template.user)
      log = create(:daily_log, plan: plan, user: template.user)
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
      create(:checklist_template, label: "A", position: 0, user: Current.user)
      create(:checklist_template, label: "B", position: 1, user: Current.user)
      restored = create(:checklist_template, label: "Old", position: 2, discarded_at: 1.day.ago, user: Current.user)

      patch restore_settings_habit_path(restored)

      expect(restored.reload.discarded_at).to be_nil
      expect(restored.position).to eq(2)
    end
  end

  describe "PATCH /settings/habits/:id/move_up and move_down" do
    let!(:templates) do
      ChecklistTemplate.delete_all
      [
        create(:checklist_template, label: "A", position: 0, user: Current.user),
        create(:checklist_template, label: "B", position: 1, user: Current.user),
        create(:checklist_template, label: "C", position: 2, user: Current.user)
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

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }

    it "index does not list another user's templates" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "Mine", position: 0, user: Current.user)
      create(:checklist_template, label: "Theirs", position: 1, user: user_b)

      get settings_habits_path

      expect(response.body).to include("Mine")
      expect(response.body).not_to include("Theirs")
    end

    it "archived does not list another user's templates" do
      ChecklistTemplate.delete_all
      create(:checklist_template, label: "MineArchived", position: 0, discarded_at: 1.day.ago, user: Current.user)
      create(:checklist_template, label: "TheirsArchived", position: 1, discarded_at: 1.day.ago, user: user_b)

      get archived_settings_habits_path

      expect(response.body).to include("MineArchived")
      expect(response.body).not_to include("TheirsArchived")
    end

    it "next_position does not leak — new template gets position 0, not the other user's count" do
      ChecklistTemplate.delete_all
      # user_b has 3 templates (positions 0,1,2)
      3.times { |i| create(:checklist_template, label: "B#{i}", position: i, user: user_b) }
      # Current.user has 0

      post settings_habits_path, params: { checklist_template: { label: "First" } }

      mine = ChecklistTemplate.find_by(label: "First", user: Current.user)
      expect(mine).to be_present
      expect(mine.position).to eq(0) # not 3
    end

    it "PATCH another user's template returns 404 and does not mutate it" do
      b = create(:checklist_template, label: "Theirs", position: 0, user: user_b)
      patch settings_habit_path(b), params: { checklist_template: { label: "Hacked" } }

      expect(response).to have_http_status(:not_found)
      expect(b.reload.label).to eq("Theirs")
    end

    it "DELETE another user's template returns 404 and does not discard it" do
      b = create(:checklist_template, label: "Theirs", position: 0, user: user_b)
      delete settings_habit_path(b)

      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).to be_nil
    end

    it "restore on another user's template returns 404 and does not restore it" do
      b = create(:checklist_template, label: "Theirs", position: 0,
                 discarded_at: 1.day.ago, user: user_b)
      patch restore_settings_habit_path(b)

      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).not_to be_nil
    end

    it "move_up on another user's template returns 404 and does not change positions" do
      ChecklistTemplate.delete_all
      a1 = create(:checklist_template, label: "A1", position: 0, user: user_b)
      a2 = create(:checklist_template, label: "A2", position: 1, user: user_b)
      b1 = create(:checklist_template, label: "B1", position: 0, user: Current.user)

      patch move_up_settings_habit_path(a2)

      expect(response).to have_http_status(:not_found)
      # The other user's siblings must be UNCHANGED — the leak would otherwise
      # let user A swap positions on user B's templates via move_up.
      expect(a1.reload.position).to eq(0)
      expect(a2.reload.position).to eq(1)
      # Sanity: user A's own template is also untouched.
      expect(b1.reload.position).to eq(0)
    end
  end
end
