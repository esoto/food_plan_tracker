require "rails_helper"

RSpec.describe BiomarkerEntry, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { goal: create(:goal), recorded_on: Date.current, value: 90.0 } }
    let(:tenantable_attrs_nil_user) { { recorded_on: Date.current, value: 87.0 } }
    let(:skip_nil_parent_test) { true }
  end

  describe "associations" do
    it { is_expected.to belong_to(:goal) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:recorded_on) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value) }
  end

  describe ".chronological" do
    it "orders by recorded_on ascending" do
      goal = create(:goal)
      older = create(:biomarker_entry, goal: goal, recorded_on: Date.current - 2, value: 90.0)
      newer = create(:biomarker_entry, goal: goal, recorded_on: Date.current,     value: 88.0)

      expect(described_class.chronological).to eq([older, newer])
    end
  end
end
