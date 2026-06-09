require "rails_helper"

RSpec.describe Settings::SupplementsController, type: :request do
  before { sign_in_as }

  describe "GET /settings/supplements" do
    it "lists kept supplements and excludes discarded" do
      kept = create(:supplement, name: "Magnesium", user: Current.user)
      _discarded = create(:supplement, name: "OldOne", discarded_at: 1.day.ago, user: Current.user)

      get settings_supplements_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Magnesium")
      expect(response.body).not_to include("OldOne")
    end
  end

  describe "GET /settings/supplements/archived" do
    it "lists only discarded supplements" do
      create(:supplement, name: "Magnesium", user: Current.user)
      create(:supplement, name: "OldOne", discarded_at: 1.day.ago, user: Current.user)

      get archived_settings_supplements_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("OldOne")
      expect(response.body).not_to include("Magnesium")
    end
  end

  describe "GET /settings/supplements/new" do
    it "renders the form" do
      get new_settings_supplement_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /settings/supplements" do
    it "creates a supplement and redirects" do
      expect {
        post settings_supplements_path, params: {
          supplement: { name: "Vitamin D", dose: "5000 IU", critical: "0" }
        }
      }.to change(Supplement, :count).by(1)

      expect(response).to redirect_to(settings_supplements_path)
      expect(Supplement.last.name).to eq("Vitamin D")
    end

    it "creates schedule rows for each checked time slot" do
      expect {
        post settings_supplements_path, params: {
          supplement: { name: "Vitamin D", dose: "5000 IU" },
          time_slots: [ "morning", "dinner" ]
        }
      }.to change(SupplementSchedule, :count).by(2)

      sup = Supplement.last
      expect(sup.supplement_schedules.pluck(:time_slot)).to contain_exactly("morning", "dinner")
    end

    it "renders new with errors when invalid" do
      post settings_supplements_path, params: { supplement: { name: "", dose: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("can&#39;t be blank")
    end
  end

  describe "GET /settings/supplements/:id/edit" do
    it "renders the form" do
      sup = create(:supplement, user: Current.user)
      get edit_settings_supplement_path(sup)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /settings/supplements/:id" do
    it "updates attributes" do
      sup = create(:supplement, name: "Old", dose: "1", user: Current.user)
      patch settings_supplement_path(sup), params: { supplement: { name: "New", dose: "2" } }

      expect(response).to redirect_to(settings_supplements_path)
      expect(sup.reload.name).to eq("New")
      expect(sup.reload.dose).to eq("2")
    end

    it "syncs schedules: adds new slots and removes unchecked ones" do
      sup = create(:supplement, user: Current.user)
      sup.supplement_schedules.create!(time_slot: "morning", position: 0)

      patch settings_supplement_path(sup), params: {
        supplement: { name: sup.name, dose: sup.dose },
        time_slots: [ "dinner", "pre_sleep" ]
      }

      expect(sup.reload.supplement_schedules.pluck(:time_slot)).to contain_exactly("dinner", "pre_sleep")
    end

    it "leaves schedules untouched when time_slots key is omitted" do
      sup = create(:supplement, user: Current.user)
      sup.supplement_schedules.create!(time_slot: "morning", position: 0)

      patch settings_supplement_path(sup), params: { supplement: { name: sup.name, dose: sup.dose } }

      expect(sup.reload.supplement_schedules.pluck(:time_slot)).to contain_exactly("morning")
    end

    it "removes all schedules when an empty time_slots array is sent" do
      sup = create(:supplement, user: Current.user)
      sup.supplement_schedules.create!(time_slot: "morning", position: 0)

      patch settings_supplement_path(sup),
            params: { supplement: { name: sup.name, dose: sup.dose }, time_slots: [] }

      expect(sup.reload.supplement_schedules).to be_empty
    end
  end

  describe "DELETE /settings/supplements/:id" do
    it "soft-deletes (discards) the supplement and preserves completion records" do
      sup = create(:supplement, user: Current.user)
      plan = create(:plan, user: sup.user)
      log = create(:daily_log, plan: plan, user: sup.user)
      completion = create(:supplement_completion, supplement: sup, daily_log: log)

      expect {
        delete settings_supplement_path(sup)
      }.not_to change(SupplementCompletion, :count)

      expect(sup.reload.discarded_at).to be_present
      expect(completion.reload).to be_persisted
    end
  end

  describe "PATCH /settings/supplements/:id/restore" do
    it "restores a discarded supplement" do
      sup = create(:supplement, discarded_at: 1.day.ago, user: Current.user)

      patch restore_settings_supplement_path(sup)

      expect(sup.reload.discarded_at).to be_nil
    end
  end

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }

    it "index does not list another user's supplements" do
      create(:supplement, name: "Mine", user: Current.user)
      create(:supplement, name: "Theirs", user: user_b)

      get settings_supplements_path

      expect(response.body).to include("Mine")
      expect(response.body).not_to include("Theirs")
    end

    it "archived does not list another user's supplements" do
      create(:supplement, name: "MineArchived", discarded_at: 1.day.ago, user: Current.user)
      create(:supplement, name: "TheirsArchived", discarded_at: 1.day.ago, user: user_b)

      get archived_settings_supplements_path

      expect(response.body).to include("MineArchived")
      expect(response.body).not_to include("TheirsArchived")
    end

    it "PATCH another user's supplement returns 404 and does not mutate it" do
      b = create(:supplement, user: user_b, name: "Original")
      patch settings_supplement_path(b), params: { supplement: { name: "Hacked" } }

      expect(response).to have_http_status(:not_found)
      # Load-bearing: even if a future change adds a rescue_from that turns
      # RecordNotFound into a 200, the foreign record must not be mutated.
      expect(b.reload.name).to eq("Original")
    end

    it "DELETE another user's supplement returns 404 and does not discard it" do
      b = create(:supplement, user: user_b)
      delete settings_supplement_path(b)

      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).to be_nil
    end

    it "restore on another user's supplement returns 404 and does not restore it" do
      b = create(:supplement, user: user_b, discarded_at: 1.day.ago)
      patch restore_settings_supplement_path(b)

      expect(response).to have_http_status(:not_found)
      expect(b.reload.discarded_at).not_to be_nil
    end
  end
end
