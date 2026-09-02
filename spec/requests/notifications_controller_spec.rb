require "rails_helper"

RSpec.describe NotificationsController, type: :request do
  let!(:user) { create(:user, password: "password12345", food_tracking_enabled: true) }
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

    it "excludes another user's push subscription" do
      user_b = create(:user)
      # Positive control: signed-in user has their own subscription that MUST appear.
      create(:push_subscription, user: user,
                                 endpoint: "https://mine.example/A",
                                 p256dh_key: "p", auth_key: "a",
                                 user_agent: "My Pixel 8")
      create(:push_subscription, user: user_b,
                                 endpoint: "https://attacker.example/push/abc",
                                 p256dh_key: "x", auth_key: "y",
                                 user_agent: "Snoop Pixel 9")

      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My Pixel 8")     # positive control
      expect(response.body).not_to include("attacker.example")
      expect(response.body).not_to include("Snoop Pixel 9")
    end

    it "excludes another user's notification delivery" do
      user_b = create(:user)
      # Positive control: signed-in user has their own delivery that MUST appear.
      NotificationDelivery.create!(title: "🍱 My breakfast reminder",
                                   body: "Time to log my Breakfast", url: "/menu",
                                   sent_count: 1, fired_at: 1.minute.ago, user: user)
      create(:notification_delivery, user: user_b,
                                     title: "B's PRIVATE NOTIFICATION",
                                     body: "should-not-leak",
                                     url: "/")

      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("🍱 My breakfast reminder") # positive control
      expect(response.body).not_to include("B's PRIVATE NOTIFICATION")
      expect(response.body).not_to include("should-not-leak")
    end

    it "shows 0 subscriptions for a new user (empty state)" do
      # The count line lives inside the PushNotifier.configured? branch. In
      # test, VAPID isn't configured, so stub it to render the body where
      # @subscription_count is exposed.
      allow(PushNotifier).to receive(:configured?).and_return(true)
      allow(PushNotifier).to receive(:public_key).and_return("BPubStubKey")

      get notifications_path

      expect(response).to have_http_status(:ok)
      # The view renders "X subscriptions registered server-side" — X should be 0.
      expect(response.body).to match(/<strong>0<\/strong>\s+subscriptions registered server-side/)
    end

    it "renders a scoped subscription count, not the global count" do
      allow(PushNotifier).to receive(:configured?).and_return(true)
      allow(PushNotifier).to receive(:public_key).and_return("BPubStubKey")

      # user (signed in) has 1 subscription; user_b has 2. The view must
      # show 1, not 3.
      create(:push_subscription, user: user,
                                 endpoint: "https://mine.example/A",
                                 p256dh_key: "p", auth_key: "a")
      user_b = create(:user)
      2.times do |i|
        create(:push_subscription, user: user_b,
                                   endpoint: "https://theirs.example/push#{i}",
                                   p256dh_key: "p", auth_key: "a")
      end

      get notifications_path

      expect(response).to have_http_status(:ok)
      # The count line must reflect just the signed-in user's 1 subscription.
      expect(response.body).to match(/<strong>1<\/strong>\s+subscription registered server-side/)
      expect(response.body).not_to match(/<strong>3<\/strong>/)
    end
  end

  describe "with food tracking disabled" do
    it "hides the meal-reminders section but still shows supplement reminders" do
      user_a = create(:user, password: "password12345", food_tracking_enabled: false)
      sign_in_as(user_a)
      Current.session = Session.create!(user: user_a, user_agent: "test", ip_address: "127.0.0.1")
      plan_a = seed_plan(slug: "active", user: user_a)
      plan_a.meals.create!(position: 1, name: "Breakfast",
                           scheduled_time: Time.utc(2000, 1, 1, 7, 30),
                           target_kcal: 450, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10, user: user_a)

      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Meal reminders")
      expect(response.body).not_to include("Breakfast")
      expect(response.body).to include("Supplement reminders")
    end
  end

  describe "with food tracking enabled (control)" do
    it "still shows the meal-reminders section unchanged" do
      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Meal reminders")
      expect(response.body).to include("Breakfast")
      expect(response.body).to include("Supplement reminders")
    end
  end
end
