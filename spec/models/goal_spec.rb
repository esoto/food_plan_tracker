require "rails_helper"

RSpec.describe Goal, type: :model do
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
