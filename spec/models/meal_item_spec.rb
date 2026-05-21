require "rails_helper"

RSpec.describe MealItem, type: :model do
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }
  let(:plan)   { create(:plan, user: user_a) }
  let(:meal)   { create(:meal, plan: plan, user: user_a) }
  let(:food)   { create(:food) }

  it_behaves_like "Tenantable", skip_for_user: true do
    let(:tenantable_attrs) { ->(user) { { meal: create(:meal, user: user), food: create(:food), quantity_grams: 50 } } }
    let(:tenantable_attrs_nil_user) { { food: create(:food), quantity_grams: 100 } }
    let(:skip_nil_parent_test) { true }
  end

  describe '.for_user' do
    it 'scopes records to the given user' do
      user_a = create(:user)
      user_b = create(:user)
      meal_a = create(:meal, user: user_a)
      meal_b = create(:meal, user: user_b)
      food_a = create(:food)
      record_a = described_class.create!(meal: meal_a, food: food_a, quantity_grams: 100)
      _record_b = described_class.create!(meal: meal_b, food: food_a, quantity_grams: 100)

      expect(described_class.for_user(user_a)).to contain_exactly(record_a)
    end

    it 'returns no records when passed nil' do
      user = create(:user)
      meal = create(:meal, user: user)
      food_a = create(:food)
      described_class.create!(meal: meal, food: food_a, quantity_grams: 100)

      expect(described_class.for_user(nil)).to be_empty
    end
  end

  describe 'before_validation callback' do
    it 'assigns Current.user on create' do
      user = create(:user)
      Current.session = Session.create!(user: user, user_agent: 'test', ip_address: '127.0.0.1')
      meal = create(:meal, user: user)
      record = described_class.new(meal: meal, food: create(:food), quantity_grams: 100)
      record.valid?
      expect(record.user).to eq(user)
    end
  end

  describe "#user_matches_meal_user" do
    it "is valid when user matches the meal's user" do
      item = build(:meal_item, meal: meal, food: food, user: user_a)
      expect(item).to be_valid
    end

    it "is invalid when user does not match the meal's user" do
      item = build(:meal_item, meal: meal, food: food, user: user_b)
      expect(item).not_to be_valid
      expect(item.errors[:user_id]).to include("must match the meal's user")
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:meal) }
    it { is_expected.to belong_to(:food) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:quantity_grams) }
    it { is_expected.to validate_numericality_of(:quantity_grams).is_greater_than(0) }

    it "requires user to match the meal's user" do
      meal = create(:meal)
      other_user = create(:user)
      item = build(:meal_item, meal: meal, food: create(:food), user: other_user)
      expect(item).not_to be_valid
      expect(item.errors[:user_id]).to include("must match the meal's user")
    end

    it "allows a matching user" do
      meal = create(:meal)
      item = build(:meal_item, meal: meal, food: create(:food), user: meal.user)
      expect(item).to be_valid
    end
  end

  describe "macros" do
    let(:food)  { build(:food, serving_grams: 100, kcal: 200, protein_g: 25, carbs_g: 10, fat_g: 5) }
    let(:meal_item) { build(:meal_item, food: food, quantity_grams: 50) }

    it "calculates ratio from serving size" do
      expect(meal_item.ratio).to eq(0.5)
    end

    it "calculates kcal" do
      expect(meal_item.kcal).to eq(100)
    end

    it "calculates protein_g" do
      expect(meal_item.protein_g).to eq(12.5)
    end

    it "calculates carbs_g" do
      expect(meal_item.carbs_g).to eq(5.0)
    end

    it "calculates fat_g" do
      expect(meal_item.fat_g).to eq(2.5)
    end

    it "returns 0 ratio when serving_grams is zero" do
      zero_serving = build(:food, serving_grams: 0)
      item = build(:meal_item, food: zero_serving, quantity_grams: 50)
      expect(item.ratio).to eq(0)
      expect(item.kcal).to eq(0)
    end
  end
end
