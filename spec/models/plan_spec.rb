require 'rails_helper'

RSpec.describe Plan, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { name: "Active", slug: "active", target_kcal: 2000, target_protein_g: 180, target_carbs_g: 180, target_fat_g: 80 } }
    let(:tenantable_attrs_b) { { name: "Exercise", slug: "exercise", target_kcal: 2200, target_protein_g: 180, target_carbs_g: 180, target_fat_g: 80 } }
    let(:tenantable_attrs_nil_user) { { name: "Rest", slug: "rest", target_kcal: 1800, target_protein_g: 160, target_carbs_g: 160, target_fat_g: 70 } }
  end

  describe "associations" do
    it { is_expected.to have_many(:meals).dependent(:destroy) }
    it { is_expected.to have_many(:daily_logs).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:target_kcal) }
    it { is_expected.to validate_presence_of(:target_protein_g) }
    it { is_expected.to validate_presence_of(:target_carbs_g) }
    it { is_expected.to validate_presence_of(:target_fat_g) }
    it { is_expected.to validate_numericality_of(:target_kcal).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:target_protein_g).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:target_carbs_g).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:target_fat_g).is_greater_than(0) }

    it "requires a unique slug" do
      create(:plan, slug: "active")
      duplicate = build(:plan, slug: "active")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include("has already been taken")
    end
  end

  describe ".exercise / .active / .rest" do
    it "finds the exercise plan by slug" do
      exercise = create(:plan, slug: "exercise")
      expect(described_class.exercise).to eq(exercise)
    end

    it "finds the active plan by slug" do
      active = create(:plan, slug: "active")
      expect(described_class.active).to eq(active)
    end

    it "finds the rest plan by slug" do
      rest = create(:plan, slug: "rest")
      expect(described_class.rest).to eq(rest)
    end

    it "returns nil when the plan does not exist" do
      expect(described_class.exercise).to be_nil
    end
  end

  describe "#exercise?" do
    it "is true when slug is exercise" do
      expect(build(:plan, slug: "exercise")).to be_exercise
    end

    it "is false for other slugs" do
      expect(build(:plan, slug: "rest")).not_to be_exercise
    end
  end
end
