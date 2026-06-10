require "rails_helper"

RSpec.describe ReminderPreferencesController, type: :request do
  let(:user) { create(:user, password: "password12345") }

  before do
    sign_in_as(user)
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
  end

  describe "PATCH /reminder_preferences" do
    it "creates a new preference row on first toggle" do
      expect {
        patch reminder_preferences_path,
              params: { reminder_type: "meal", key: "Breakfast", enabled: "false" }
      }.to change(ReminderPreference, :count).by(1)

      pref = ReminderPreference.last
      expect(pref.reminder_type).to eq("meal")
      expect(pref.key).to eq("Breakfast")
      expect(pref.enabled).to be false

      expect(response).to redirect_to(notifications_path)
    end

    it "updates an existing preference row" do
      ReminderPreference.create!(reminder_type: "supplement_slot", key: "morning", enabled: false, user: user)

      expect {
        patch reminder_preferences_path,
              params: { reminder_type: "supplement_slot", key: "morning", enabled: "true" }
      }.not_to change(ReminderPreference, :count)

      expect(ReminderPreference.find_by(reminder_type: "supplement_slot", key: "morning").enabled).to be true
    end

    it "treats checkbox absence as false (browser doesn't send unchecked)" do
      patch reminder_preferences_path,
            params: { reminder_type: "meal", key: "Lunch", enabled: "false" }

      expect(ReminderPreference.find_by(reminder_type: "meal", key: "Lunch").enabled).to be false
    end

    it "rejects with 4xx when reminder_type is missing" do
      expect {
        patch reminder_preferences_path,
              params: { key: "Breakfast", enabled: "false" }
      }.not_to change(ReminderPreference, :count)

      expect(response).to have_http_status(:bad_request)
    end

    it "toggling a reminder does not affect another user's preference for the same key" do
      other = create(:user)
      ReminderPreference.create!(reminder_type: "meal", key: "Breakfast", enabled: true, user: other)

      patch reminder_preferences_path,
            params: { reminder_type: "meal", key: "Breakfast", enabled: "false" }

      # Signed-in user's row was updated.
      expect(ReminderPreference.find_by(reminder_type: "meal", key: "Breakfast", user: user).enabled).to be false
      # Other user's row is untouched.
      expect(ReminderPreference.find_by(reminder_type: "meal", key: "Breakfast", user: other).enabled).to be true
    end

    it "creating a preference for the signed-in user does not create one for another user" do
      other = create(:user)

      expect {
        patch reminder_preferences_path,
              params: { reminder_type: "meal", key: "Lunch", enabled: "true" }
      }.to change { ReminderPreference.where(user: user, reminder_type: "meal", key: "Lunch").count }.from(0).to(1)

      expect(ReminderPreference.where(user: other, reminder_type: "meal", key: "Lunch")).to be_empty
    end
  end
end
