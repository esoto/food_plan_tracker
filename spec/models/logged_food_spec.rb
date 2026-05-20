require 'rails_helper'

RSpec.describe LoggedFood, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { daily_log: create(:daily_log), food: create(:food), quantity_grams: 100, logged_at: Time.current } }
    let(:tenantable_attrs_nil_user) { { food: create(:food), quantity_grams: 100, logged_at: Time.current } }
  end
end
