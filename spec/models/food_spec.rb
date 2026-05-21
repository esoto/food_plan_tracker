require "rails_helper"

RSpec.describe Food, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:meal_items).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:logged_foods).dependent(:restrict_with_error) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_presence_of(:serving_grams) }
    it { is_expected.to validate_presence_of(:kcal) }
    it { is_expected.to validate_presence_of(:protein_g) }
    it { is_expected.to validate_presence_of(:carbs_g) }
    it { is_expected.to validate_presence_of(:fat_g) }

    it "requires a unique name scoped to category" do
      create(:food, name: "Chicken", category: :protein)
      duplicate = build(:food, name: "Chicken", category: :protein)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "allows the same name in different categories" do
      create(:food, name: "Chicken", category: :protein)
      other = build(:food, name: "Chicken", category: :fat)
      expect(other).to be_valid
    end
  end

  describe "enums" do
    it "defines category enum values" do
      expect(described_class.categories.keys).to contain_exactly("protein", "carb", "fat", "vegetable")
    end
  end

  describe "#category_label" do
    it "returns a human label for the category" do
      expect(build(:food, category: :protein).category_label).to eq("Protein")
      expect(build(:food, category: :vegetable).category_label).to eq("Veggies")
    end
  end

  describe "#category_colors" do
    it "returns a color hash for the category" do
      colors = build(:food, category: :carb).category_colors
      expect(colors).to include(:tint, :ring, :text, :dot)
    end
  end
end
