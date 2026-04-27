require "rails_helper"

RSpec.describe ReminderPreferencesController, type: :request do
  before { sign_in_as }

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
      ReminderPreference.create!(reminder_type: "supplement_slot", key: "morning", enabled: false)

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
  end
end
