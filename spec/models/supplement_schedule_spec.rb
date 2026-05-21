require 'rails_helper'

RSpec.describe SupplementSchedule, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { supplement: create(:supplement), time_slot: 1, position: 1 } }
    let(:tenantable_attrs_nil_user) { { time_slot: 1, position: 1 } }
  end
end
