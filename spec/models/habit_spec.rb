require "rails_helper"

RSpec.describe Habit, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { label: "Test", position: 1 } }
  end

  before { Habit.delete_all }

  describe ".next_position" do
    let(:user) { create(:user) }

    it "returns 0 when there are no kept records for the user" do
      expect(described_class.next_position(user: user)).to eq(0)
    end

    it "returns max(position) + 1 over the user's kept records, ignoring discarded" do
      create(:habit, position: 0, user: user)
      create(:habit, position: 5, user: user)
      create(:habit, position: 99, discarded_at: 1.day.ago, user: user)

      expect(described_class.next_position(user: user)).to eq(6)
    end

    it "isolates positions between users" do
      create(:habit, position: 0, user: user)
      other = create(:user)
      create(:habit, position: 7, user: other)

      expect(described_class.next_position(user: user)).to eq(1)
    end

    it "defaults to Current.user" do
      Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
      create(:habit, position: 3, user: user)
      expect(described_class.next_position).to eq(4)
    end

    it "returns 0 when Current.user is nil and no user is provided" do
      create(:habit, position: 7, user: create(:user)) # noise: another user's kept record
      Current.reset
      expect(described_class.next_position).to eq(0)
    end
  end

  describe "kind" do
    it "defaults to binary" do
      habit = create(:habit)
      expect(habit.kind).to eq("binary")
      expect(habit).to be_binary
    end

    it "exposes the full set of kinds" do
      expect(described_class.kinds).to eq(
        "binary" => 0, "quantity" => 1, "duration" => 2, "rating" => 3
      )
    end
  end

  describe ".scoreable" do
    it "excludes rating habits and includes every other kind" do
      binary = create(:habit)
      quantity = create(:habit, :quantity)
      duration = create(:habit, :duration)
      create(:habit, :rating)

      expect(described_class.scoreable).to contain_exactly(binary, quantity, duration)
    end
  end

  describe "kind-specific validations" do
    context "binary" do
      it "is valid without unit, target_value, or rating_scale" do
        expect(build(:habit, kind: :binary)).to be_valid
      end

      it "forbids unit" do
        habit = build(:habit, kind: :binary, unit: "glasses")
        expect(habit).not_to be_valid
        expect(habit.errors[:unit]).to be_present
      end
    end

    context "rating" do
      it "is valid with a rating_scale and no unit/target_value" do
        expect(build(:habit, :rating)).to be_valid
      end

      it "requires rating_scale" do
        habit = build(:habit, kind: :rating, rating_scale: nil)
        expect(habit).not_to be_valid
        expect(habit.errors[:rating_scale]).to be_present
      end

      it "requires rating_scale to be an integer between 2 and 10" do
        expect(build(:habit, :rating, rating_scale: 1)).not_to be_valid
        expect(build(:habit, :rating, rating_scale: 11)).not_to be_valid
        expect(build(:habit, :rating, rating_scale: 2.5)).not_to be_valid
        expect(build(:habit, :rating, rating_scale: 2)).to be_valid
        expect(build(:habit, :rating, rating_scale: 10)).to be_valid
      end

      it "forbids target_value" do
        habit = build(:habit, :rating, target_value: 5)
        expect(habit).not_to be_valid
        expect(habit.errors[:target_value]).to be_present
      end

      it "forbids unit" do
        habit = build(:habit, :rating, unit: "stars")
        expect(habit).not_to be_valid
        expect(habit.errors[:unit]).to be_present
      end
    end

    context "quantity" do
      it "allows unit and target_value, forbids rating_scale" do
        expect(build(:habit, :quantity)).to be_valid

        habit = build(:habit, :quantity, rating_scale: 5)
        expect(habit).not_to be_valid
        expect(habit.errors[:rating_scale]).to be_present
      end
    end

    context "duration" do
      it "allows unit and target_value, forbids rating_scale" do
        expect(build(:habit, :duration)).to be_valid

        habit = build(:habit, :duration, rating_scale: 5)
        expect(habit).not_to be_valid
        expect(habit.errors[:rating_scale]).to be_present
      end
    end

    context "target_value" do
      it "must be greater than 0 when present" do
        expect(build(:habit, :quantity, target_value: 0)).not_to be_valid
        expect(build(:habit, :quantity, target_value: -1)).not_to be_valid
        expect(build(:habit, :quantity, target_value: nil)).to be_valid
      end
    end
  end

  describe "#restore_at_end!" do
    let(:user) { create(:user) }

    it "clears discarded_at and appends after the existing kept tail" do
      create(:habit, label: "A", position: 0, user: user)
      create(:habit, label: "B", position: 1, user: user)
      restored = create(:habit, label: "Old", position: 99, discarded_at: 1.day.ago, user: user)

      restored.restore_at_end!

      expect(restored.reload.discarded_at).to be_nil
      expect(restored.position).to eq(2)
    end

    it "uses position 0 when no other kept records exist" do
      restored = create(:habit, label: "Only", position: 5, discarded_at: 1.day.ago, user: user)

      restored.restore_at_end!

      expect(restored.reload.position).to eq(0)
    end

    it "rolls back the position update if restore raises" do
      restored = create(:habit, position: 99, discarded_at: 1.day.ago, user: user)
      allow(restored).to receive(:restore!).and_raise(ActiveRecord::RecordInvalid.new(restored))

      expect { restored.restore_at_end! }.to raise_error(ActiveRecord::RecordInvalid)

      restored.reload
      expect(restored.discarded_at).to be_present
      expect(restored.position).to eq(99)
    end
  end
end
