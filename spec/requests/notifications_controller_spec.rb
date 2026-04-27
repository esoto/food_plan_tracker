require "rails_helper"

RSpec.describe NotificationsController, type: :request do
  let!(:plan) { seed_plan(slug: "active") }
  let!(:meal) do
    plan.meals.create!(position: 1, name: "Breakfast",
                       scheduled_time: Time.utc(2000, 1, 1, 7, 30),
                       target_kcal: 450, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10)
  end

  before { sign_in_as }

  describe "GET /notifications" do
    it "renders the page with all four sections" do
      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("This device")
      expect(response.body).to include("Subscribed devices")
      expect(response.body).to include("Meal reminders")
      expect(response.body).to include("Supplement reminders")
      expect(response.body).to include("Recent deliveries")
    end

    it "lists subscribed devices with their user_agent" do
      PushSubscription.create!(endpoint: "https://fcm.example/A", p256dh_key: "p", auth_key: "a", user_agent: "Pixel 8 Chrome")

      get notifications_path

      expect(response.body).to include("Pixel 8 Chrome")
    end

    it "renders a toggle row for each meal in today's plan" do
      get notifications_path
      expect(response.body).to include("Breakfast")
    end

    it "shows recent deliveries" do
      NotificationDelivery.create!(title: "🍱 Breakfast time", body: "Time to log Breakfast", url: "/menu",
                                   sent_count: 1, fired_at: 1.minute.ago)

      get notifications_path

      expect(response.body).to include("🍱 Breakfast time")
      expect(response.body).to include("1 sent")
    end
  end
end
