require 'rails_helper'

RSpec.describe MealItem, type: :model do
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }
  let(:plan)   { create(:plan, user: user_a) }
  let(:meal)   { create(:meal, plan: plan, user: user_a) }
  let(:food)   { create(:food) }

  it_behaves_like "Tenantable", skip_for_user: true do
    let(:tenantable_attrs) { { meal: create(:meal), food: create(:food), quantity_grams: 100 } }
    let(:tenantable_attrs_nil_user) { { food: create(:food), quantity_grams: 100 } }
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
end
