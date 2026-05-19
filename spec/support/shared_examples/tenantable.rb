# frozen_string_literal: true

RSpec.shared_examples 'Tenantable' do
  it { is_expected.to belong_to(:user).optional }

  describe '.for_user' do
    it 'scopes records to the given user' do
      user_a = create(:user)
      user_b = create(:user)
      record_a = described_class.create!(user: user_a)
      _record_b = described_class.create!(user: user_b)

      expect(described_class.for_user(user_a)).to eq([record_a])
    end

    it 'returns no records when passed nil' do
      user = create(:user)
      described_class.create!(user: user)

      expect(described_class.for_user(nil)).to be_empty
    end
  end

  describe 'before_validation callback' do
    it 'assigns Current.user on create' do
      user = create(:user)
      Current.user = user
      record = described_class.new
      record.valid?
      expect(record.user).to eq(user)
    end

    it 'leaves user nil when Current.user is nil and no parent association' do
      Current.user = nil
      record = described_class.new
      record.valid?
      expect(record.user).to be_nil
    end
  end
end
