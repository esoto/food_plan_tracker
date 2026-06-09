require 'rails_helper'

RSpec.describe PushSubscription, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { endpoint: "https://test.example.com/push/123", p256dh_key: "test_p256dh", auth_key: "test_auth" } }
    let(:tenantable_attrs_b) { { endpoint: "https://test.example.com/push/456", p256dh_key: "test_p256dh_b", auth_key: "test_auth_b" } }
    let(:tenantable_attrs_nil_user) { { endpoint: "https://test.example.com/push/789", p256dh_key: "test_p256dh_nil", auth_key: "test_auth_nil" } }
  end

  describe "per-user endpoint uniqueness (cross-tenant isolation)" do
    it "allows two different users to each register the same endpoint" do
      user_a = create(:user)
      user_b = create(:user)
      shared_endpoint = "https://fcm.googleapis.com/fcm/send/shared-device"

      sub_a = described_class.create!(user: user_a, endpoint: shared_endpoint, p256dh_key: "p_a", auth_key: "a_a")
      sub_b = described_class.create!(user: user_b, endpoint: shared_endpoint, p256dh_key: "p_b", auth_key: "a_b")

      expect(sub_a).to be_persisted
      expect(sub_b).to be_persisted
      expect(described_class.where(endpoint: shared_endpoint).count).to eq(2)
    end

    it "still prevents the same user from creating two rows with the same endpoint" do
      user = create(:user)
      endpoint = "https://fcm.googleapis.com/fcm/send/dup-endpoint"
      p256dh = "p1"
      auth = "a1"

      described_class.create!(user: user, endpoint: endpoint, p256dh_key: p256dh, auth_key: auth)

      duplicate = described_class.new(user: user, endpoint: endpoint, p256dh_key: "p2", auth_key: "a2")
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "supports upsert semantics within a user (find_or_initialize_by endpoint stays inside the user)" do
      user = create(:user)
      endpoint = "https://fcm.googleapis.com/fcm/send/upsert"

      sub = described_class.find_or_initialize_by(user: user, endpoint: endpoint)
      sub.update!(p256dh_key: "first", auth_key: "first_auth")
      first_id = sub.id

      sub2 = described_class.find_or_initialize_by(user: user, endpoint: endpoint)
      sub2.update!(p256dh_key: "second", auth_key: "second_auth")

      expect(sub2.id).to eq(first_id)
      expect(sub2.reload.p256dh_key).to eq("second")
      expect(described_class.where(user: user, endpoint: endpoint).count).to eq(1)
    end
  end
end
