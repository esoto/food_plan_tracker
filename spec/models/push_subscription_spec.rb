require 'rails_helper'

RSpec.describe PushSubscription, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { endpoint: "https://test.example.com/push/123", p256dh_key: "test_p256dh", auth_key: "test_auth" } }
    let(:tenantable_attrs_b) { { endpoint: "https://test.example.com/push/456", p256dh_key: "test_p256dh_b", auth_key: "test_auth_b" } }
    let(:tenantable_attrs_nil_user) { { endpoint: "https://test.example.com/push/789", p256dh_key: "test_p256dh_nil", auth_key: "test_auth_nil" } }
  end
end
