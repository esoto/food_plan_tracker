require "rails_helper"

RSpec.describe MealCompletion, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:daily_log) }
    it { is_expected.to belong_to(:meal) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:completed_at) }

    it "requires a unique meal per daily_log" do
      daily_log = create(:daily_log)
      meal      = create(:meal, plan: daily_log.plan)
      create(:meal_completion, daily_log: daily_log, meal: meal)

      duplicate = build(:meal_completion, daily_log: daily_log, meal: meal)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:meal_id]).to include("has already been taken")
    end
  end
end
