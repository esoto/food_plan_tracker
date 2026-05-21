# frozen_string_literal: true

RSpec.shared_examples 'Tenantable' do |skip_for_user: false|
  let(:tenantable_attrs) { {} }
  let(:tenantable_attrs_b) { tenantable_attrs }
  let(:tenantable_attrs_nil_user) { tenantable_attrs }

  it { is_expected.to belong_to(:user).optional }

  describe '.for_user' do
    unless skip_for_user
      it 'scopes records to the given user' do
        user_a = create(:user)
        user_b = create(:user)
        record_a = described_class.create!(tenantable_attrs.merge(user: user_a))
        _record_b = described_class.create!(tenantable_attrs_b.merge(user: user_b))

        expect(described_class.for_user(user_a)).to contain_exactly(record_a)
      end

      it 'returns no records when passed nil' do
        user = create(:user)
        described_class.create!(tenantable_attrs.merge(user: user))

        expect(described_class.for_user(nil)).to be_empty
      end
    end
  end

  describe 'before_validation callback' do
    it 'assigns Current.user on create' do
      user = create(:user)
      Current.session = Session.create!(user: user, user_agent: 'test', ip_address: '127.0.0.1')
      record = described_class.new(tenantable_attrs)
      record.valid?
      expect(record.user).to eq(user)
    end

    it 'leaves user nil when Current.user is nil and no parent association' do
      Current.reset
      record = described_class.new(tenantable_attrs_nil_user)
      record.valid?
      expect(record.user).to be_nil
    end
  end
end
