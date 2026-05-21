require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:plans).dependent(:destroy) }
    it { is_expected.to have_many(:meals).dependent(:destroy) }
    it { is_expected.to have_many(:daily_logs).dependent(:destroy) }
    it { is_expected.to have_many(:supplements).dependent(:destroy) }
    it { is_expected.to have_many(:supplement_schedules).dependent(:destroy) }
    it { is_expected.to have_many(:goals).dependent(:destroy) }
    it { is_expected.to have_many(:biomarker_entries).dependent(:destroy) }
    it { is_expected.to have_many(:checklist_templates).dependent(:destroy) }
    it { is_expected.to have_many(:logged_foods).dependent(:destroy) }
    it { is_expected.to have_many(:api_tokens).dependent(:destroy) }
    it { is_expected.to have_many(:push_subscriptions).dependent(:destroy) }
    it { is_expected.to have_many(:reminder_preferences).dependent(:destroy) }
    it { is_expected.to have_many(:notification_deliveries).dependent(:destroy) }
    it { is_expected.to have_many(:meal_items).dependent(:destroy) }
  end

  describe "normalizations" do
    it "strips and downcases the email address" do
      user = create(:user, email_address: "  Hello@Example.COM  ")
      expect(user.email_address).to eq("hello@example.com")
    end
  end
end
