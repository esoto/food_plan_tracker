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

  describe ".set_value!" do
    it "creates a row on first call and updates the same row on subsequent calls" do
      daily_log = create(:daily_log)
      habit = create(:habit, :quantity, user: daily_log.user)

      expect {
        described_class.set_value!(daily_log: daily_log, habit: habit, value: 3)
      }.to change(described_class, :count).by(1)

      expect {
        described_class.set_value!(daily_log: daily_log, habit: habit, value: 5)
      }.not_to change(described_class, :count)

      entry = described_class.find_by(daily_log: daily_log, habit: habit)
      expect(entry.reload.value).to eq(5.0)
    end

    it "sets the checked COLUMN true when value > 0 (post-reload, bypassing any model cache)" do
      daily_log = create(:daily_log)
      habit = create(:habit, :quantity, user: daily_log.user)

      described_class.set_value!(daily_log: daily_log, habit: habit, value: 4)

      entry = described_class.find_by(daily_log: daily_log, habit: habit)
      expect(entry.reload.checked).to eq(true)
    end

    it "sets the checked COLUMN false when value is 0 (post-reload)" do
      daily_log = create(:daily_log)
      habit = create(:habit, :quantity, user: daily_log.user)

      described_class.set_value!(daily_log: daily_log, habit: habit, value: 0)

      entry = described_class.find_by(daily_log: daily_log, habit: habit)
      expect(entry.reload.checked).to eq(false)
    end

    it "raises InvalidValue and writes nothing when a rating value exceeds the habit's scale" do
      daily_log = create(:daily_log)
      habit = create(:habit, :rating, user: daily_log.user, rating_scale: 5)

      expect {
        described_class.set_value!(daily_log: daily_log, habit: habit, value: 6)
      }.to raise_error(HabitEntry::InvalidValue)

      expect(described_class.find_by(daily_log: daily_log, habit: habit)).to be_nil
    end
  end

  describe ".increment_value!" do
    it "sums the value across multiple calls" do
      daily_log = create(:daily_log)
      habit = create(:habit, :quantity, user: daily_log.user)

      described_class.increment_value!(daily_log: daily_log, habit: habit, delta: 3)
      described_class.increment_value!(daily_log: daily_log, habit: habit, delta: 2)

      entry = described_class.find_by(daily_log: daily_log, habit: habit)
      expect(entry.reload.value).to eq(5.0)
    end

    it "flips the checked COLUMN true once the summed value is positive" do
      daily_log = create(:daily_log)
      habit = create(:habit, :quantity, user: daily_log.user)

      described_class.increment_value!(daily_log: daily_log, habit: habit, delta: 3)
      described_class.increment_value!(daily_log: daily_log, habit: habit, delta: 2)

      entry = described_class.find_by(daily_log: daily_log, habit: habit)
      expect(entry.reload.checked).to eq(true)
    end

    it "clamps the result at 0 (never negative) via GREATEST(0, ...) and flips checked false" do
      daily_log = create(:daily_log)
      habit = create(:habit, :quantity, user: daily_log.user)

      described_class.increment_value!(daily_log: daily_log, habit: habit, delta: 2)
      described_class.increment_value!(daily_log: daily_log, habit: habit, delta: -5)

      entry = described_class.find_by(daily_log: daily_log, habit: habit)
      entry.reload
      expect(entry.value).to eq(0.0)
      expect(entry.checked).to eq(false)
    end

    it "raises InvalidValue and writes nothing when called on a rating habit" do
      daily_log = create(:daily_log)
      habit = create(:habit, :rating, user: daily_log.user, rating_scale: 5)

      expect {
        described_class.increment_value!(daily_log: daily_log, habit: habit, delta: 1)
      }.to raise_error(HabitEntry::InvalidValue)

      expect(described_class.find_by(daily_log: daily_log, habit: habit)).to be_nil
    end
  end
end
