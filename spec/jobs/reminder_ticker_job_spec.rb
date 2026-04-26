require "rails_helper"

RSpec.describe ReminderTickerJob, type: :job do
  let!(:plan) do
    Plan.find_or_create_by!(slug: "active") do |p|
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
                       target_kcal: 450, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10)
  end
  let!(:lunch) do
    plan.meals.create!(position: 2, name: "Lunch",
                       scheduled_time: Time.utc(2000, 1, 1, 12, 30),
                       target_kcal: 600, target_protein_g: 45, target_carbs_g: 60, target_fat_g: 20)
  end
  let!(:supp_a) { Supplement.create!(name: "Vitamin D", dose: "1000 IU") }
  let!(:supp_b) { Supplement.create!(name: "Magnesium", dose: "400mg") }
  let!(:morning_a) { SupplementSchedule.create!(supplement: supp_a, time_slot: :morning, position: 1) }
  let!(:morning_b) { SupplementSchedule.create!(supplement: supp_b, time_slot: :morning, position: 2) }

  before do
    allow(PushNotifier).to receive(:configured?).and_return(true)
    allow(PushNotifier).to receive(:broadcast)
  end

  describe "no-op behavior" do
    it "does nothing when push isn't configured" do
      allow(PushNotifier).to receive(:configured?).and_return(false)
      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 7, 30))
    end

    it "does nothing on an off-minute (no meal or supplement scheduled)" do
      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 9, 17))
    end
  end

  describe "meal reminders" do
    it "fires when current minute matches a meal's scheduled_time and the meal is uncompleted" do
      DailyLog.today # ensure today's log exists

      expect(PushNotifier).to receive(:broadcast).with(
        title: "🍱 Breakfast time",
        body:  /Breakfast.*450 kcal/,
        url:   "/menu"
      )

      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 7, 30))
    end

    it "does NOT fire if the meal is already completed today" do
      DailyLog.today.meal_completions.create!(meal: breakfast, completed_at: Time.current)

      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 7, 30))
    end

    it "matches by hour+minute, not date — fires today even if scheduled_time year is 2000" do
      DailyLog.today

      expect(PushNotifier).to receive(:broadcast).once
      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 12, 30))
    end
  end

  describe "supplement reminders" do
    it "fires one combined reminder per slot at the slot's representative time" do
      DailyLog.today

      expect(PushNotifier).to receive(:broadcast).with(
        title: "💊 Morning supplements",
        body:  "2 supplements due now.",
        url:   "/supplements"
      )

      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 7, 0))
    end

    it "skips supplements already taken today and only counts the rest" do
      log = DailyLog.today
      log.supplement_completions.create!(supplement: supp_a, taken_at: Time.current)

      expect(PushNotifier).to receive(:broadcast).with(
        title: "💊 Morning supplements",
        body:  "1 supplement due now.",
        url:   "/supplements"
      )

      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 7, 0))
    end

    it "does not fire if all supplements in the slot are already taken" do
      log = DailyLog.today
      log.supplement_completions.create!(supplement: supp_a, taken_at: Time.current)
      log.supplement_completions.create!(supplement: supp_b, taken_at: Time.current)

      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 7, 0))
    end
  end

  describe "dual fire (meal + supplement at the same minute)" do
    it "broadcasts both the meal and the supplement-slot push" do
      # pre_lunch slot fires at 11:45; add a supplement to that slot
      # AND create a meal at the same minute.
      SupplementSchedule.create!(supplement: supp_a, time_slot: :pre_lunch, position: 1)
      plan.meals.create!(position: 99, name: "Pre-lunch snack",
                         scheduled_time: Time.utc(2000, 1, 1, 11, 45),
                         target_kcal: 200, target_protein_g: 10, target_carbs_g: 20, target_fat_g: 5)
      DailyLog.today

      expect(PushNotifier).to receive(:broadcast).with(hash_including(title: "🍱 Pre-lunch snack time"))
      expect(PushNotifier).to receive(:broadcast).with(hash_including(title: "💊 Pre Lunch supplements"))

      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 11, 45))
    end
  end
end
