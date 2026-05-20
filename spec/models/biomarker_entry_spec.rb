require 'rails_helper'

RSpec.describe BiomarkerEntry, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { goal: create(:goal), recorded_on: Date.current, value: 87.0 } }
    let(:tenantable_attrs_nil_user) { { recorded_on: Date.current, value: 87.0 } }
  end
end
