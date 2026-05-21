require "rails_helper"

RSpec.describe ChecklistCompletion, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:daily_log) }
    it { is_expected.to belong_to(:checklist_template) }
  end

  describe "validations" do
    it "requires a unique checklist_template per daily_log" do
      daily_log = create(:daily_log)
      template  = create(:checklist_template)
      create(:checklist_completion, daily_log: daily_log, checklist_template: template)

      duplicate = build(:checklist_completion, daily_log: daily_log, checklist_template: template)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:checklist_template_id]).to include("has already been taken")
    end
  end
end
