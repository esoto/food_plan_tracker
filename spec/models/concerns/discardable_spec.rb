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

  describe ".kept_on(date)" do
    it "includes records still kept (no discarded_at)" do
      kept = create(:supplement)
      expect(Supplement.kept_on(Date.current)).to include(kept)
    end

    it "includes records discarded after the given day ended" do
      sup = create(:supplement, discarded_at: Date.current.end_of_day + 1.minute)
      expect(Supplement.kept_on(Date.current)).to include(sup)
    end

    it "excludes records discarded before the given day ended" do
      sup = create(:supplement, discarded_at: Date.current.beginning_of_day)
      expect(Supplement.kept_on(Date.current)).not_to include(sup)
    end

    it "for a past date, includes a record discarded after that date" do
      sup = create(:supplement, discarded_at: 1.day.ago.end_of_day + 1.minute)
      expect(Supplement.kept_on(2.days.ago.to_date)).to include(sup)
      expect(Supplement.kept_on(Date.current)).not_to include(sup)
    end
  end

  describe ".kept_on cross-tenant isolation" do
    it "excludes other users' records when chained after for_user" do
      user_a = create(:user)
      user_b = create(:user)
      mine   = create(:supplement, user: user_a)
      create(:supplement, user: user_b)

      results = Supplement.for_user(user_a).kept_on(Date.current)

      expect(results).to contain_exactly(mine)
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
