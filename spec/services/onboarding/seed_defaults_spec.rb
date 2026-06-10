require "rails_helper"

RSpec.describe Onboarding::SeedDefaults do
  describe ".call" do
    let!(:other_user) { create(:user) }
    let!(:user)       { create(:user) }

    it "creates exactly 3 plans for the user" do
      expect { described_class.call(user) }.to change { user.plans.count }.from(0).to(3)
    end

    it "creates plans with the documented target macros" do
      described_class.call(user)

      exercise = user.plans.find_by!(slug: Plan::EXERCISE_SLUG)
      expect(exercise.name).to eq("Exercise day")
      expect(exercise.target_kcal).to eq(2100)
      expect(exercise.target_protein_g).to eq(180)
      expect(exercise.target_carbs_g).to eq(215)
      expect(exercise.target_fat_g).to eq(75)

      active = user.plans.find_by!(slug: Plan::ACTIVE_SLUG)
      expect(active.name).to eq("Active day")
      expect(active.target_kcal).to eq(2075)
      expect(active.target_protein_g).to eq(180)
      expect(active.target_carbs_g).to eq(180)
      expect(active.target_fat_g).to eq(80)

      rest = user.plans.find_by!(slug: Plan::REST_SLUG)
      expect(rest.name).to eq("Rest day")
      expect(rest.target_kcal).to eq(2050)
      expect(rest.target_protein_g).to eq(180)
      expect(rest.target_carbs_g).to eq(160)
      expect(rest.target_fat_g).to eq(85)
    end

    it "returns the user" do
      result = described_class.call(user)
      expect(result).to eq(user)
    end

    it "is idempotent — calling twice creates no duplicate plans" do
      described_class.call(user)
      expect { described_class.call(user) }.not_to change { user.plans.count }
    end

    it "does NOT overwrite a customized plan's targets" do
      described_class.call(user)
      user.plans.find_by!(slug: Plan::ACTIVE_SLUG).update!(target_kcal: 1800)

      described_class.call(user)

      expect(user.plans.find_by!(slug: Plan::ACTIVE_SLUG).target_kcal).to eq(1800)
    end

    it "does NOT touch another user's plans" do
      create(:plan, slug: Plan::ACTIVE_SLUG, user: other_user)
      other_count_before = other_user.plans.count

      described_class.call(user)

      expect(other_user.plans.count).to eq(other_count_before)
      expect(Plan.where(user: other_user).pluck(:user_id).uniq).to eq([ other_user.id ])
    end
  end
end
