require "rails_helper"

RSpec.describe Supplement, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { name: "Vitamin D", dose: "1 capsule" } }
  end

  describe "#sync_time_slots!" do
    let(:supplement) { create(:supplement) }

    it "creates schedule rows for newly checked slots" do
      expect {
        supplement.sync_time_slots!([ "morning", "dinner" ])
      }.to change(SupplementSchedule, :count).by(2)

      expect(supplement.supplement_schedules.pluck(:time_slot)).to contain_exactly("morning", "dinner")
    end

    it "removes rows for slots that are no longer checked" do
      supplement.supplement_schedules.create!(time_slot: "morning", position: 0)
      supplement.supplement_schedules.create!(time_slot: "dinner", position: 0)

      supplement.sync_time_slots!([ "morning" ])

      expect(supplement.reload.supplement_schedules.pluck(:time_slot)).to contain_exactly("morning")
    end

    it "removes all rows when an empty array is passed" do
      supplement.supplement_schedules.create!(time_slot: "morning", position: 0)

      supplement.sync_time_slots!([])

      expect(supplement.reload.supplement_schedules).to be_empty
    end

    it "ignores unknown slot keys (and the empty-string sentinel from HTML forms)" do
      supplement.sync_time_slots!([ "morning", "bogus", "" ])
      expect(supplement.supplement_schedules.pluck(:time_slot)).to contain_exactly("morning")
    end

    it "appends at the end of existing positions in the slot" do
      other = create(:supplement)
      other.supplement_schedules.create!(time_slot: "morning", position: 0)
      other.supplement_schedules.create!(time_slot: "morning", position: 1)

      supplement.sync_time_slots!([ "morning" ])

      expect(supplement.supplement_schedules.first.position).to eq(2)
    end

    it "is a no-op when slot set is unchanged" do
      supplement.supplement_schedules.create!(time_slot: "morning", position: 0)
      original_id = supplement.supplement_schedules.first.id

      supplement.sync_time_slots!([ "morning" ])

      expect(supplement.supplement_schedules.first.id).to eq(original_id)
    end

    it "rolls back the whole sync when a destroy fails" do
      supplement.supplement_schedules.create!(time_slot: "morning", position: 0)

      allow_any_instance_of(SupplementSchedule).to receive(:destroy!)
        .and_raise(ActiveRecord::RecordNotDestroyed.new("boom"))

      expect {
        supplement.sync_time_slots!([ "dinner" ])
      }.to raise_error(ActiveRecord::RecordNotDestroyed)

      expect(supplement.reload.supplement_schedules.pluck(:time_slot)).to contain_exactly("morning")
    end
  end
end
