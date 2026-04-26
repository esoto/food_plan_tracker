require "rails_helper"

RSpec.describe Discardable do
  # Use Supplement as a representative including model.
  let(:record) { create(:supplement) }

  describe "scopes" do
    it "kept includes records with discarded_at IS NULL" do
      kept = create(:supplement)
      discarded = create(:supplement, discarded_at: 1.hour.ago)
      expect(Supplement.kept).to include(kept)
      expect(Supplement.kept).not_to include(discarded)
    end

    it "discarded includes only records with discarded_at set" do
      kept = create(:supplement)
      discarded = create(:supplement, discarded_at: 1.hour.ago)
      expect(Supplement.discarded).to contain_exactly(discarded)
      expect(Supplement.discarded).not_to include(kept)
    end
  end

  describe "#discard!" do
    it "sets discarded_at to current time" do
      freeze_time do
        record.discard!
        expect(record.reload.discarded_at).to be_within(1.second).of(Time.current)
      end
    end

    it "is idempotent — does not update timestamp on a second call" do
      record.discard!
      first_at = record.reload.discarded_at
      travel 5.seconds do
        record.discard!
        expect(record.reload.discarded_at).to eq(first_at)
      end
    end
  end

  describe "#restore!" do
    it "clears discarded_at on a discarded record" do
      record.discard!
      record.restore!
      expect(record.reload.discarded_at).to be_nil
    end

    it "no-ops on a kept record" do
      expect { record.restore! }.not_to change { record.reload.updated_at }
    end
  end

  describe "predicates" do
    it "discarded? reflects state" do
      expect(record.discarded?).to be false
      record.discard!
      expect(record.discarded?).to be true
    end

    it "kept? is the inverse" do
      expect(record.kept?).to be true
      record.discard!
      expect(record.kept?).to be false
    end
  end
end
