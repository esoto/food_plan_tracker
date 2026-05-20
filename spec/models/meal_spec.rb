require "rails_helper"

RSpec.describe Meal, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { plan: create(:plan), position: 1, name: "Breakfast", scheduled_time: Time.utc(2000, 1, 1, 7, 0), target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10 } }
    let(:tenantable_attrs_b) { { plan: create(:plan), position: 1, name: "Lunch", scheduled_time: Time.utc(2000, 1, 1, 12, 0), target_kcal: 600, target_protein_g: 45, target_carbs_g: 60, target_fat_g: 20 } }
    let(:tenantable_attrs_nil_user) { { position: 1, name: "Dinner", scheduled_time: Time.utc(2000, 1, 1, 19, 0), target_kcal: 500, target_protein_g: 40, target_carbs_g: 55, target_fat_g: 15 } }
  end

  describe "#scheduled_time= (HH:MM string coercion)" do
    let(:plan) { create(:plan) }
    let(:meal) { build(:meal, plan: plan) }

    it "coerces a valid HH:MM string to the UTC sentinel Time" do
      meal.scheduled_time = "13:45"
      expect(meal.scheduled_time).to eq(Time.utc(2000, 1, 1, 13, 45))
    end

    it "accepts single-digit hour" do
      meal.scheduled_time = "7:30"
      expect(meal.scheduled_time).to eq(Time.utc(2000, 1, 1, 7, 30))
    end

    it "passes through a real Time object unchanged" do
      t = Time.utc(2000, 1, 1, 8, 15)
      meal.scheduled_time = t
      expect(meal.scheduled_time).to eq(t)
    end

    it "passes through nil unchanged" do
      meal.scheduled_time = nil
      expect(meal.scheduled_time).to be_nil
    end

    it "raises Meal::InvalidScheduledTime on a non-HH:MM string" do
      expect { meal.scheduled_time = "not-a-time" }.to raise_error(Meal::InvalidScheduledTime, /HH:MM/)
    end

    it "raises Meal::InvalidScheduledTime on out-of-range hour" do
      expect { meal.scheduled_time = "25:00" }.to raise_error(Meal::InvalidScheduledTime, /0-23/)
    end

    it "raises Meal::InvalidScheduledTime on out-of-range minute" do
      expect { meal.scheduled_time = "12:60" }.to raise_error(Meal::InvalidScheduledTime, /0-59/)
    end

    it "raises Meal::InvalidScheduledTime on single-digit minute (12:5)" do
      expect { meal.scheduled_time = "12:5" }.to raise_error(Meal::InvalidScheduledTime, /HH:MM/)
    end

    it "raises Meal::InvalidScheduledTime on leading whitespace" do
      expect { meal.scheduled_time = " 12:30" }.to raise_error(Meal::InvalidScheduledTime, /HH:MM/)
    end

    it "does NOT silently overflow on values like 99:99 (regression guard)" do
      expect { meal.scheduled_time = "99:99" }.to raise_error(Meal::InvalidScheduledTime)
    end
  end
end
