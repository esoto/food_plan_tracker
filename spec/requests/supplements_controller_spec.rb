require "rails_helper"

RSpec.describe "GET /supplements", type: :request do
  before do
    sign_in_as
    create(:plan, slug: "exercise", name: "Exercise day", user: Current.user)
  end

  describe "happy path" do
    it "renders the supplements dashboard" do
      get supplements_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Supplements")
    end

    it "lists the signed-in user's kept supplements grouped by time slot" do
      sup = create(:supplement, name: "Magnesium", user: Current.user)
      sup.supplement_schedules.create!(time_slot: "pre_sleep", position: 0)

      get supplements_path

      expect(response.body).to include("Magnesium")
    end

    it "omits discarded supplements" do
      create(:supplement, name: "Magnesium", user: Current.user)
      create(:supplement, name: "OldOne", discarded_at: 1.day.ago, user: Current.user)

      get supplements_path

      expect(response.body).to include("Magnesium")
      expect(response.body).not_to include("OldOne")
    end

    it "renders the critical-warnings block when a critical supplement has contraindications" do
      create(:supplement, name: "Fibrotina", critical: true,
                          contraindications: "Statins · Grapefruit juice", user: Current.user)

      get supplements_path

      expect(response.body).to include("Do not combine with Fibrotina")
      expect(response.body).to include("Statins")
      expect(response.body).to include("Grapefruit juice")
    end
  end

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }

    it "does not render another user's supplement rows" do
      mine = create(:supplement, name: "Mine", user: Current.user)
      mine.supplement_schedules.create!(time_slot: "morning", position: 0)

      foreign = create(:supplement, name: "Theirs", user: user_b)
      foreign.supplement_schedules.create!(time_slot: "morning", position: 0)

      get supplements_path

      expect(response.body).to include("Mine")
      expect(response.body).not_to include("Theirs")
    end

    it "does not include another user's supplements in the critical-warnings block" do
      create(:supplement, name: "Mine", critical: true,
                          contraindications: "My contraindication", user: Current.user)
      create(:supplement, name: "Theirs", critical: true,
                          contraindications: "SECRET_WARNING_B", user: user_b)

      get supplements_path

      expect(response.body).to include("My contraindication")
      expect(response.body).not_to include("SECRET_WARNING_B")
    end

    it "scopes the inner JOIN through Current.user's supplements only" do
      # Build a foreign supplement_schedule that the user_id filter MUST
      # reject. If the controller's @grouped is unscoped, the inner
      # `.merge(Current.user.supplements.kept)` is what blocks the foreign
      # row. We assert by name absence.
      mine = create(:supplement, name: "MineRow", user: Current.user)
      mine.supplement_schedules.create!(time_slot: "morning", position: 0)

      foreign = create(:supplement, name: "ForeignRow", user: user_b)
      foreign.supplement_schedules.create!(time_slot: "dinner", position: 0)

      get supplements_path

      expect(response.body).to include("MineRow")
      expect(response.body).not_to include("ForeignRow")
    end
  end
end
