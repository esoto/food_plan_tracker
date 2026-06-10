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

  describe "created_by_user tracking" do
    let(:user) { create(:user) }

    it "records created_by_user when Current.user is set" do
      food = nil
      Current.set(user: user) do
        food = Food.create!(
          name: "Custom protein",
          category: :protein,
          serving_grams: 100,
          kcal: 150,
          protein_g: 25,
          carbs_g: 0,
          fat_g: 5
        )
      end
      expect(food.reload.created_by_user).to eq(user)
    end

    it "leaves created_by_user nil when Current.user is not set" do
      Current.set(user: nil) do
        food = Food.create!(
          name: "Seeded food",
          category: :protein,
          serving_grams: 100,
          kcal: 150,
          protein_g: 25,
          carbs_g: 0,
          fat_g: 5
        )
        expect(food.reload.created_by_user).to be_nil
      end
    end
  end

  describe ".seeded scope" do
    it "includes only foods with created_by_user_id = nil" do
      user = create(:user)
      seeded = create(:food, name: "Chicken", created_by_user: nil)
      custom = Current.set(user: user) do
        create(:food, name: "Turkey", category: :protein)
      end

      expect(Food.seeded).to include(seeded)
      expect(Food.seeded).not_to include(custom)
    end
  end

  describe "prune guard" do
    it "destroys stale seeded foods but spares user-created foods" do
      user = create(:user)
      # Create one seeded food not in the allowed list
      stale_seeded = create(:food, name: "Old Spanish Food", category: :protein, created_by_user: nil)
      # Create one user-created food not in the allowed list
      custom = Current.set(user: user) do
        create(:food, name: "User Custom Food", category: :protein)
      end
      # Create one seeded food that is in the allowed list
      canonical = create(:food, name: "Chicken breast, cooked", category: :protein, created_by_user: nil)

      # Replicate the prune logic from db/seeds.rb with a small allowed set
      allowed_food_keys = [["Chicken breast, cooked", Food.categories["protein"]]]
      Food.seeded.find_each do |food|
        food.destroy unless allowed_food_keys.include?([food.name, food.category_before_type_cast])
      end

      expect { stale_seeded.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { custom.reload }.not_to raise_error, "user-created food should survive the prune"
      expect { canonical.reload }.not_to raise_error, "canonical food should survive the prune"
    end
  end
end
