require 'rails_helper'

RSpec.describe Plan, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { name: "Active", slug: "active", target_kcal: 2000, target_protein_g: 180, target_carbs_g: 180, target_fat_g: 80 } }
    let(:tenantable_attrs_b) { { name: "Exercise", slug: "exercise", target_kcal: 2200, target_protein_g: 180, target_carbs_g: 180, target_fat_g: 80 } }
    let(:tenantable_attrs_nil_user) { { name: "Rest", slug: "rest", target_kcal: 1800, target_protein_g: 160, target_carbs_g: 160, target_fat_g: 70 } }
  end
end
