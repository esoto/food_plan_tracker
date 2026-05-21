require "rails_helper"

RSpec.describe SupplementSchedule, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { supplement: create(:supplement), time_slot: :morning, position: 0 } }
    let(:tenantable_attrs_nil_user) { { time_slot: 1, position: 1 } }
    let(:skip_nil_parent_test) { true }
  end

  describe "associations" do
    it { is_expected.to belong_to(:supplement) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:time_slot) }
    it { is_expected.to validate_presence_of(:position) }
  end

  describe "enums" do
    it "defines time_slot enum values" do
      expect(described_class.time_slots.keys).to contain_exactly("morning", "pre_lunch", "dinner", "pre_sleep")
    end
  end

  describe "#slot_label" do
    it "returns a human label for the time slot" do
      expect(build(:supplement_schedule, time_slot: :morning).slot_label).to eq("Morning")
      expect(build(:supplement_schedule, time_slot: :pre_sleep).slot_label).to eq("Before bed")
    end
  end

  describe "#slot_time" do
    it "returns a wall-clock time string for the time slot" do
      expect(build(:supplement_schedule, time_slot: :pre_lunch).slot_time).to eq("11:45 AM")
      expect(build(:supplement_schedule, time_slot: :dinner).slot_time).to eq("7:30 PM")
    end
  end
end
