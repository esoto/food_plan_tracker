# frozen_string_literal: true

require 'rails_helper'

# Ephemeral test models for Tenantable concern verification.
# These tables are created inline so the spec is independent of PER-564.
#
# `TenantableTestRecord` declares `belongs_to :meal` (aliased to
# `TenantableTestParent`) specifically so the fallback test exercises the
# `meal&.user` branch of `Tenantable#assign_current_user`. If you rename
# or remove the `meal` branch in the concern, update this association too.
class TenantableTestParent < ApplicationRecord
  self.table_name = 'tenantable_test_parents'
  belongs_to :user
end

class TenantableTestRecord < ApplicationRecord
  self.table_name = 'tenantable_test_records'
  include Tenantable
  belongs_to :meal, class_name: 'TenantableTestParent',
                     foreign_key: :tenantable_test_parent_id, optional: true
end

RSpec.describe Tenantable, type: :model do
  before(:all) do
    ActiveRecord::Base.connection.create_table :tenantable_test_parents, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    ActiveRecord::Base.connection.create_table :tenantable_test_records, if_not_exists: true do |t|
      t.references :user, null: true, foreign_key: true
      t.references :tenantable_test_parent, null: true, foreign_key: true
      t.timestamps
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :tenantable_test_records, if_exists: true
    ActiveRecord::Base.connection.drop_table :tenantable_test_parents, if_exists: true
  end

  describe TenantableTestRecord do
    it_behaves_like 'Tenantable'
  end

  describe 'parent association fallback' do
    let(:parent_user) { create(:user) }
    let(:parent) { TenantableTestParent.create!(user: parent_user) }

    it 'derives user from a parent association when Current.user is nil' do
      Current.reset
      record = TenantableTestRecord.new(meal: parent)
      record.valid?
      expect(record.user).to eq(parent_user)
    end

    it 'prefers Current.user over parent association' do
      current_user = create(:user)
      Current.session = Session.create!(user: current_user, user_agent: 'test', ip_address: '127.0.0.1')
      record = TenantableTestRecord.new(meal: parent)
      record.valid?
      expect(record.user).to eq(current_user)
    end
  end

  describe 'meta-test: user_id column presence' do
    it 'verifies every Tenantable model has a user_id column' do
      pending 'unblocks after PER-553 adds user_id columns to all Tenantable models'

      Rails.application.eager_load! unless Rails.application.config.eager_load

      tenantable_models = ApplicationRecord.descendants.select do |model|
        model.included_modules.include?(Tenantable) && model.table_exists?
      end

      # Exclude ephemeral test models; only check production models.
      tenantable_models.reject! { |m| m.name&.start_with?('TenantableTest') }

      # Ensure the pending test actually fails while no production models exist.
      expect(tenantable_models).not_to be_empty,
                                       'No production Tenantable models found yet'

      missing = tenantable_models.reject do |model|
        model.column_names.include?('user_id')
      end

      expect(missing).to be_empty,
                         "Missing user_id on: #{missing.map(&:name).join(', ')}"
    end
  end
end
