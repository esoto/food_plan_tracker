require "rails_helper"

RSpec.describe ChecklistTemplate, type: :model do
  before { ChecklistTemplate.delete_all }

  describe ".next_position" do
    it "returns 0 when there are no kept records" do
      expect(ChecklistTemplate.next_position).to eq(0)
    end

    it "returns max(position) + 1 over kept records, ignoring discarded" do
      create(:checklist_template, position: 0)
      create(:checklist_template, position: 5)
      create(:checklist_template, position: 99, discarded_at: 1.day.ago)

      expect(ChecklistTemplate.next_position).to eq(6)
    end
  end

  describe "#restore_at_end!" do
    it "clears discarded_at and appends after the existing kept tail" do
      create(:checklist_template, label: "A", position: 0)
      create(:checklist_template, label: "B", position: 1)
      restored = create(:checklist_template, label: "Old", position: 99, discarded_at: 1.day.ago)

      restored.restore_at_end!

      expect(restored.reload.discarded_at).to be_nil
      expect(restored.position).to eq(2)
    end

    it "uses position 0 when no other kept records exist" do
      restored = create(:checklist_template, label: "Only", position: 5, discarded_at: 1.day.ago)

      restored.restore_at_end!

      expect(restored.reload.position).to eq(0)
    end

    it "rolls back the position update if restore raises" do
      restored = create(:checklist_template, position: 99, discarded_at: 1.day.ago)
      allow(restored).to receive(:restore!).and_raise(ActiveRecord::RecordInvalid.new(restored))

      expect { restored.restore_at_end! }.to raise_error(ActiveRecord::RecordInvalid)

      restored.reload
      expect(restored.discarded_at).to be_present
      expect(restored.position).to eq(99)
    end
  end
end
