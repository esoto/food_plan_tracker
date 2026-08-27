require "rails_helper"

RSpec.describe HabitEntry, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:daily_log) }
    it { is_expected.to belong_to(:habit) }
  end

  describe "validations" do
    it "requires a unique habit per daily_log" do
      daily_log = create(:daily_log)
      template  = create(:habit)
      create(:habit_entry, daily_log: daily_log, habit: template)

      duplicate = build(:habit_entry, daily_log: daily_log, habit: template)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:habit_id]).to include("has already been taken")
    end
  end
end
