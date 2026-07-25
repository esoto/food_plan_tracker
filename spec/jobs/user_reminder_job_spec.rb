require "rails_helper"

RSpec.describe UserReminderJob, type: :job do
  let(:user) { create(:user) }
  let!(:plan) do
    Plan.find_or_create_by!(slug: "active", user: user) do |p|
      p.name = "Active day"
      p.target_kcal = 2000
      p.target_protein_g = 180
      p.target_carbs_g = 180
      p.target_fat_g = 70
    end
  end
  let!(:breakfast) do
    plan.meals.create!(position: 1, name: "Breakfast",
                       scheduled_time: Time.utc(2000, 1, 1, 7, 30),
                       target_kcal: 450, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10, user: user)
  end
  let!(:lunch) do
    plan.meals.create!(position: 2, name: "Lunch",
                       scheduled_time: Time.utc(2000, 1, 1, 12, 30),
                       target_kcal: 600, target_protein_g: 45, target_carbs_g: 60, target_fat_g: 20, user: user)
  end
  let!(:supp_a) { Supplement.create!(name: "Vitamin D", dose: "1000 IU", user: user) }
  let!(:supp_b) { Supplement.create!(name: "Magnesium", dose: "400mg", user: user) }
  let!(:morning_a) { SupplementSchedule.create!(supplement: supp_a, time_slot: :morning, position: 1) }
  let!(:morning_b) { SupplementSchedule.create!(supplement: supp_b, time_slot: :morning, position: 2) }

  before do
    allow(PushNotifier).to receive(:configured?).and_return(true)
    allow(PushNotifier).to receive(:broadcast).and_call_original
  end

  describe "context establishment" do
    it "sets Current.user inside and RESETS it afterward" do
      expect(Current.user).to be_nil

      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))

      expect(Current.user).to be_nil
    end

    it "RESETS Current.user even when the broadcast raises" do
      DailyLog.for(Date.current, user: user)
      allow(PushNotifier).to receive(:broadcast).and_raise(StandardError, "push 5xx")

      expect {
        described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))
      }.to raise_error(StandardError, "push 5xx")

      # Current.set restores in an ensure — a raise inside the block must not
      # leak this user's context into the next job on the same worker thread.
      expect(Current.user).to be_nil
    end
  end

  describe "no-op behavior" do
    it "no-ops for a vanished user without raising" do
      expect(PushNotifier).not_to receive(:broadcast)
      expect { described_class.perform_now(-1, now: Time.zone.local(2026, 4, 26, 7, 30)) }.not_to raise_error
    end

    it "no-ops for a deactivated user even with a due, uncompleted meal" do
      DailyLog.for(Date.current, user: user)
      user.update!(deactivated_at: Time.current)

      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))
    end

    it "does nothing when push isn't configured" do
      allow(PushNotifier).to receive(:configured?).and_return(false)
      DailyLog.for(Date.current, user: user)

      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))
    end

    it "does nothing on an off-minute (no meal or supplement scheduled)" do
      DailyLog.for(Date.current, user: user)

      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 9, 17))
    end
  end

  describe "meal reminders" do
    it "fires when current minute matches a meal's scheduled_time and the meal is uncompleted" do
      DailyLog.for(Date.current, user: user)

      expect(PushNotifier).to receive(:broadcast).with(hash_including(
        title: "🍱 Breakfast time",
        body:  /Breakfast.*450 kcal/,
        url:   "/menu",
        user:  user
      ))

      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))
    end

    it "does NOT fire if the meal is already completed today" do
      today = DailyLog.for(Date.current, user: user)
      today.meal_completions.create!(meal: breakfast, completed_at: Time.current)

      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))
    end

    it "matches by hour+minute, not date — fires today even if scheduled_time year is 2000" do
      DailyLog.for(Date.current, user: user)

      expect(PushNotifier).to receive(:broadcast).once
      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 12, 30))
    end
  end

  describe "supplement reminders" do
    it "fires one combined reminder per slot at the slot's representative time" do
      DailyLog.for(Date.current, user: user)

      expect(PushNotifier).to receive(:broadcast).with(hash_including(
        title: "💊 Morning supplements",
        body:  "2 supplements due now.",
        url:   "/supplements",
        user:  user
      ))

      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 0))
    end

    it "skips supplements already taken today and only counts the rest" do
      today = DailyLog.for(Date.current, user: user)
      today.supplement_completions.create!(supplement: supp_a, taken_at: Time.current)

      expect(PushNotifier).to receive(:broadcast).with(hash_including(
        title: "💊 Morning supplements",
        body:  "1 supplement due now.",
        url:   "/supplements",
        user:  user
      ))

      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 0))
    end

    it "does not fire if all supplements in the slot are already taken" do
      today = DailyLog.for(Date.current, user: user)
      today.supplement_completions.create!(supplement: supp_a, taken_at: Time.current)
      today.supplement_completions.create!(supplement: supp_b, taken_at: Time.current)

      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 0))
    end
  end

  describe "preference gate" do
    it "skips a meal reminder when its preference is disabled" do
      DailyLog.for(Date.current, user: user)
      ReminderPreference.set(reminder_type: "meal", key: "Breakfast", enabled: false, user: user)

      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))
    end

    it "skips a supplement-slot reminder when its preference is disabled" do
      DailyLog.for(Date.current, user: user)
      ReminderPreference.set(reminder_type: "supplement_slot", key: "morning", enabled: false, user: user)

      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 0))
    end
  end

  describe "dual fire (meal + supplement at the same minute)" do
    it "broadcasts both the meal and the supplement-slot push" do
      SupplementSchedule.create!(supplement: supp_a, time_slot: :pre_lunch, position: 1)
      plan.meals.create!(position: 99, name: "Pre-lunch snack",
                         scheduled_time: Time.utc(2000, 1, 1, 11, 45),
                         target_kcal: 200, target_protein_g: 10, target_carbs_g: 20, target_fat_g: 5, user: user)
      DailyLog.for(Date.current, user: user)

      expect(PushNotifier).to receive(:broadcast).with(hash_including(title: "🍱 Pre-lunch snack time", user: user))
      expect(PushNotifier).to receive(:broadcast).with(hash_including(title: "💊 Pre Lunch supplements", user: user))

      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 11, 45))
    end
  end

  describe "cross-tenant isolation" do
    let(:other) { create(:user) }
    let!(:other_plan) do
      Plan.find_or_create_by!(slug: "active", user: other) do |p|
        p.name = "Other plan"
        p.target_kcal = 2000
        p.target_protein_g = 180
        p.target_carbs_g = 180
        p.target_fat_g = 70
      end
    end
    let!(:other_supp) { Supplement.create!(name: "Zinc", dose: "25mg", user: other) }
    let!(:other_morning) { SupplementSchedule.create!(supplement: other_supp, time_slot: :morning, position: 1) }

    it "does NOT let user B's disabled preference suppress user A's reminder" do
      DailyLog.for(Date.current, user: user)
      ReminderPreference.set(reminder_type: "meal", key: "Breakfast", enabled: false, user: other)

      expect(PushNotifier).to receive(:broadcast).with(hash_including(
        title: "🍱 Breakfast time",
        user:  user
      ))

      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))
    end

    it "does NOT count user B's supplements in user A's slot total" do
      DailyLog.for(Date.current, user: user)

      expect(PushNotifier).to receive(:broadcast).with(hash_including(
        title: "💊 Morning supplements",
        body:  "2 supplements due now.",
        user:  user
      ))

      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 0))
    end

    it "operates on user A's own daily log, not an arbitrary user's" do
      # Create other user's log FIRST (before A) so unscoped find_by returns B's log
      other_log = DailyLog.for(Date.current, user: other)
      other_plan_2 = Plan.find_or_create_by!(slug: "other_plan", user: other) do |p|
        p.name = "Other Plan"
        p.target_kcal = 2000
        p.target_protein_g = 180
        p.target_carbs_g = 180
        p.target_fat_g = 70
      end
      other_log.update!(plan: other_plan_2)
      # B's plan has a different meal at 7:30 (uncompleted in B's log)
      other_meal = other_plan_2.meals.create!(position: 1, name: "Early Snack",
                                              scheduled_time: Time.utc(2000, 1, 1, 7, 30),
                                              target_kcal: 200, target_protein_g: 10, target_carbs_g: 20, target_fat_g: 5, user: other)

      # Create user A's log AFTER B's (A uses the original plan with breakfast)
      user_log = DailyLog.for(Date.current, user: user)
      # A's log has the breakfast meal COMPLETED
      user_log.meal_completions.create!(meal: breakfast, completed_at: Time.current)

      # Scoped: reads A's log → A's plan → A's "Breakfast" meal at 7:30 (completed) → no broadcast.
      # Unscoped: reads B's log → B's plan → B's "Early Snack" meal at 7:30 (uncompleted) →
      # broadcasts B's meal title — so the guard must be "no broadcast AT ALL", not a
      # title-specific .never (the leaked broadcast carries the foreign title).
      expect(PushNotifier).not_to receive(:broadcast)

      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))
    end
  end

  describe "delivery side-effects" do
    it "creates audit NotificationDelivery with sent_count 0 for a user with no push subscription" do
      DailyLog.for(Date.current, user: user)
      ENV["VAPID_PUBLIC_KEY"] = "test_public"
      ENV["VAPID_PRIVATE_KEY"] = "test_private"

      described_class.perform_now(user.id, now: Time.zone.local(2026, 4, 26, 7, 30))

      delivery = NotificationDelivery.find_by(user: user, title: "🍱 Breakfast time")
      expect(delivery).to be_present
      expect(delivery.sent_count).to eq(0)
    ensure
      ENV.delete("VAPID_PUBLIC_KEY")
      ENV.delete("VAPID_PRIVATE_KEY")
    end
  end
end
