require "rails_helper"

RSpec.describe ReminderPreference, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { reminder_type: "meal", key: "Breakfast", enabled: true } }
    let(:tenantable_attrs_b) { { reminder_type: "meal", key: "Lunch", enabled: true } }
    let(:tenantable_attrs_nil_user) { { reminder_type: "supplement_slot", key: "morning", enabled: true } }
  end

  let(:user) { create(:user) }

  before do
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
  end

  describe ".enabled?" do
    it "is true by default when no row exists" do
      expect(described_class.enabled?(reminder_type: "meal", key: "Breakfast")).to be true
    end

    it "is false when a row says so" do
      described_class.create!(reminder_type: "meal", key: "Breakfast", enabled: false, user: user)
      expect(described_class.enabled?(reminder_type: "meal", key: "Breakfast")).to be false
    end

    it "is true when a row explicitly enables it" do
      described_class.create!(reminder_type: "meal", key: "Lunch", enabled: true, user: user)
      expect(described_class.enabled?(reminder_type: "meal", key: "Lunch")).to be true
    end
  end

  describe ".set" do
    it "creates a new row on first call" do
      expect {
        described_class.set(reminder_type: "supplement_slot", key: "morning", enabled: false)
      }.to change(described_class, :count).by(1)
    end

    it "updates the existing row on subsequent calls" do
      described_class.set(reminder_type: "supplement_slot", key: "morning", enabled: false)

      expect {
        described_class.set(reminder_type: "supplement_slot", key: "morning", enabled: true)
      }.not_to change(described_class, :count)

      expect(described_class.enabled?(reminder_type: "supplement_slot", key: "morning")).to be true
    end
  end

  describe "validations" do
    it "rejects an unknown reminder_type" do
      pref = described_class.new(reminder_type: "made_up", key: "x", enabled: true, user: user)
      expect(pref).not_to be_valid
      expect(pref.errors[:reminder_type]).to be_present
    end

    it "rejects duplicate (reminder_type, key)" do
      described_class.create!(reminder_type: "meal", key: "Breakfast", enabled: true, user: user)
      dupe = described_class.new(reminder_type: "meal", key: "Breakfast", enabled: false, user: user)
      expect(dupe).not_to be_valid
    end
  end
end
