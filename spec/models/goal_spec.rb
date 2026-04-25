require "rails_helper"

RSpec.describe Goal, type: :model do
  describe ".with_measurements" do
    it "returns goals that have at least one biomarker entry" do
      tracked = create(:goal, :weight, :with_measurement, measurement_value: 90.0)
      _untracked = create(:goal)
      expect(Goal.with_measurements).to contain_exactly(tracked)
    end

    it "excludes goals with no biomarker entries" do
      create(:goal)
      create(:goal, :preserve)
      expect(Goal.with_measurements).to be_empty
    end

    it "deduplicates goals that have multiple biomarker entries" do
      goal = create(:goal, :weight)
      create(:biomarker_entry, goal: goal, recorded_on: Date.current - 1, value: 91.0)
      create(:biomarker_entry, goal: goal, recorded_on: Date.current,     value: 90.0)
      expect(Goal.with_measurements).to eq([goal])
    end
  end

  describe "#show_progress_bar?" do
    context "when the goal has measurements" do
      it "is true for a directional goal" do
        goal = create(:goal, :with_measurement, measurement_value: 20.0)
        expect(goal.show_progress_bar?).to be true
      end

      it "is true for a preserve goal" do
        goal = create(:goal, :preserve, :with_measurement, measurement_value: 67.0)
        expect(goal.show_progress_bar?).to be true
      end
    end

    context "when the goal has no measurements" do
      it "is false for a directional goal" do
        goal = create(:goal)
        expect(goal.show_progress_bar?).to be false
      end

      it "is false for a preserve goal (regression: avoid showing a 100% bar with 'No readings yet')" do
        goal = create(:goal, :preserve)
        expect(goal.show_progress_bar?).to be false
      end
    end
  end
end
