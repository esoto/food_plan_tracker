require "rails_helper"

RSpec.describe SupplementCompletion, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:daily_log) }
    it { is_expected.to belong_to(:supplement) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:taken_at) }

    it "requires a unique supplement per daily_log" do
      daily_log = create(:daily_log)
      supplement  = create(:supplement)
      create(:supplement_completion, daily_log: daily_log, supplement: supplement)

      duplicate = build(:supplement_completion, daily_log: daily_log, supplement: supplement)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:supplement_id]).to include("has already been taken")
    end
  end
end
