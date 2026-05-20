require "rails_helper"

RSpec.describe NotificationsController, type: :request do
  let!(:user) { create(:user, password: "password") }
  let!(:plan) { seed_plan(slug: "active") }
  let!(:meal) do
    plan.meals.create!(position: 1, name: "Breakfast",
                       scheduled_time: Time.utc(2000, 1, 1, 7, 30),
                       target_kcal: 450, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10, user: user)
  end

  before do
    sign_in_as(user)
    Current.session = Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")
  end

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
      PushSubscription.create!(endpoint: "https://fcm.example/A", p256dh_key: "p", auth_key: "a", user_agent: "Pixel 8 Chrome", user: user)

      get notifications_path

      expect(response.body).to include("Pixel 8 Chrome")
    end

    it "renders a toggle row for each meal in today's plan" do
      get notifications_path
      expect(response.body).to include("Breakfast")
    end

    it "shows recent deliveries" do
      NotificationDelivery.create!(title: "🍱 Breakfast time", body: "Time to log Breakfast", url: "/menu",
                                   sent_count: 1, fired_at: 1.minute.ago, user: user)

      get notifications_path

      expect(response.body).to include("🍱 Breakfast time")
      expect(response.body).to include("1 sent")
    end

    it "renders without a 500 when today's plan can't be resolved" do
      # Force the today_log lookup to return one without a plan. We can't
      # set plan_id to nil (NOT NULL constraint), so stub the helper.
      allow_any_instance_of(NotificationsController).to receive(:today_log).and_return(double(plan: nil))

      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Meal reminders")
      expect(response.body).to include("Supplement reminders") # still rendered
    end
  end
end
