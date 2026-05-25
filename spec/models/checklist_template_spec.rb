require "rails_helper"

RSpec.describe ChecklistTemplate, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { label: "Test", position: 1 } }
  end

  before { ChecklistTemplate.delete_all }

  describe ".next_position" do
    let(:user) { create(:user) }

    it "returns 0 when there are no kept records for the user" do
      expect(described_class.next_position(user: user)).to eq(0)
    end

    it "returns max(position) + 1 over the user's kept records, ignoring discarded" do
      create(:checklist_template, position: 0, user: user)
      create(:checklist_template, position: 5, user: user)
      create(:checklist_template, position: 99, discarded_at: 1.day.ago, user: user)

      expect(described_class.next_position(user: user)).to eq(6)
    end

    it "isolates positions between users" do
      create(:checklist_template, position: 0, user: user)
      other = create(:user)
      create(:checklist_template, position: 7, user: other)

      expect(described_class.next_position(user: user)).to eq(1)
    end

    it "defaults to Current.user" do
      Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
      create(:checklist_template, position: 3, user: user)
      expect(described_class.next_position).to eq(4)
    end

    it "returns 0 when Current.user is nil and no user is provided" do
      Current.reset
      expect(described_class.next_position).to eq(0)
    end
  end

  describe "#restore_at_end!" do
    let(:user) { create(:user) }

    it "clears discarded_at and appends after the existing kept tail" do
      create(:checklist_template, label: "A", position: 0, user: user)
      create(:checklist_template, label: "B", position: 1, user: user)
      restored = create(:checklist_template, label: "Old", position: 99, discarded_at: 1.day.ago, user: user)

      restored.restore_at_end!

      expect(restored.reload.discarded_at).to be_nil
      expect(restored.position).to eq(2)
    end

    it "uses position 0 when no other kept records exist" do
      restored = create(:checklist_template, label: "Only", position: 5, discarded_at: 1.day.ago, user: user)

      restored.restore_at_end!

      expect(restored.reload.position).to eq(0)
    end

    it "rolls back the position update if restore raises" do
      restored = create(:checklist_template, position: 99, discarded_at: 1.day.ago, user: user)
      allow(restored).to receive(:restore!).and_raise(ActiveRecord::RecordInvalid.new(restored))

      expect { restored.restore_at_end! }.to raise_error(ActiveRecord::RecordInvalid)

      restored.reload
      expect(restored.discarded_at).to be_present
      expect(restored.position).to eq(99)
    end
  end
end
