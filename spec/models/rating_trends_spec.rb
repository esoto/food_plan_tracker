require "rails_helper"

RSpec.describe RatingTrends, type: :model do
  let(:user) { create(:user) }
  let!(:plan) { create(:plan, user: user) }

  describe ".for" do
    it "returns an empty array when the user has no kept rating habits" do
      create(:habit, :quantity, user: user, label: "Water", position: 0)

      expect(described_class.for(user)).to eq([])
    end

    it "excludes discarded rating habits" do
      habit = create(:habit, :rating, user: user, label: "Journaling", position: 0)
      habit.discard!

      expect(described_class.for(user)).to eq([])
    end

    it "computes avg7, prev_avg7, and a 14-day points sparkline for a kept rating habit" do
      habit = create(:habit, :rating, user: user, label: "Mood", position: 0)
      today = Date.current

      # Previous 7-day window (13..7 days ago): avg 2.0
      13.downto(7).each do |days_ago|
        log = DailyLog.create!(date: today - days_ago, plan: plan)
        create(:habit_entry, daily_log: log, habit: habit, value: 2)
      end

      # Last 7-day window (6..1 days ago logged, today left unlogged): avg 4.0
      6.downto(1).each do |days_ago|
        log = DailyLog.create!(date: today - days_ago, plan: plan)
        create(:habit_entry, daily_log: log, habit: habit, value: 4)
      end

      trends = described_class.for(user, today: today)

      expect(trends.size).to eq(1)
      trend = trends.first
      expect(trend[:habit]).to eq(habit)
      expect(trend[:avg7]).to eq(4.0)
      expect(trend[:prev_avg7]).to eq(2.0)
      expect(trend[:points].size).to eq(14)
      expect(trend[:points].first).to eq([ today - 13, 2.0 ])
      expect(trend[:points].last).to eq([ today, nil ])
    end

    it "scopes to the given user only" do
      other = create(:user)
      create(:habit, :rating, user: other, label: "Theirs", position: 0)

      expect(described_class.for(user)).to eq([])
    end
  end
end
