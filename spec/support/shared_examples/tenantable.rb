# frozen_string_literal: true

RSpec.shared_examples 'Tenantable' do |skip_for_user: false|
  let(:tenantable_attrs) { {} }
  let(:tenantable_attrs_b) { tenantable_attrs }
  let(:tenantable_attrs_nil_user) { tenantable_attrs }
  let(:skip_nil_parent_test) { false }

  describe 'belongs_to requirement' do
    before { Current.reset }
    it { is_expected.to belong_to(:user) }
  end

  describe '.for_user' do
    unless skip_for_user
      it 'scopes records to the given user' do
        user_a = create(:user)
        user_b = create(:user)
        attrs_a = tenantable_attrs.respond_to?(:call) ? tenantable_attrs.call(user_a) : tenantable_attrs
        attrs_b = tenantable_attrs.respond_to?(:call) ? tenantable_attrs.call(user_b) : tenantable_attrs_b
        record_a = described_class.create!(attrs_a.merge(user: user_a))
        _record_b = described_class.create!(attrs_b.merge(user: user_b))

        expect(described_class.for_user(user_a)).to contain_exactly(record_a)
      end

      it 'returns no records when passed nil' do
        user = create(:user)
        attrs = tenantable_attrs.respond_to?(:call) ? tenantable_attrs.call(user) : tenantable_attrs
        described_class.create!(attrs.merge(user: user))

        expect(described_class.for_user(nil)).to be_empty
      end
    end
  end

  describe 'before_validation callback' do
    it 'assigns Current.user on create' do
      user = create(:user)
      Current.session = Session.create!(user: user, user_agent: 'test', ip_address: '127.0.0.1')
      attrs = tenantable_attrs.respond_to?(:call) ? tenantable_attrs.call(user) : tenantable_attrs
      record = described_class.new(attrs)
      record.valid?
      expect(record.user).to eq(user)
    end

    it 'leaves user nil when Current.user is nil and no parent association' do
      skip if skip_nil_parent_test

      Current.reset
      record = described_class.new(tenantable_attrs_nil_user)
      record.valid?
      expect(record.user).to be_nil
    end
  end
end
