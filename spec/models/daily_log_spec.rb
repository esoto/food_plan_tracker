require 'rails_helper'

RSpec.describe DailyLog, type: :model do
  it_behaves_like "Tenantable" do
    let(:tenantable_attrs) { { date: Date.current, plan: create(:plan) } }
    let(:tenantable_attrs_b) { { date: Date.yesterday, plan: create(:plan) } }
    let(:tenantable_attrs_nil_user) { { date: Date.current - 2 } }
    let(:skip_nil_parent_test) { true }
  end

  let(:user) { create(:user) }
  let!(:plan) { Plan.find_or_create_by!(slug: "active", user: user) { |p| p.name = "Active day"; p.target_kcal = 2000; p.target_protein_g = 180; p.target_carbs_g = 180; p.target_fat_g = 70 } }
  let(:other_plan) { Plan.find_or_create_by!(slug: "exercise", user: user) { |p| p.name = "Exercise day"; p.target_kcal = 2200; p.target_protein_g = 180; p.target_carbs_g = 180; p.target_fat_g = 70 } }
  let(:meal_a) { plan.meals.create!(position: 1, name: "A", scheduled_time: Time.utc(2000, 1, 1, 7, 0), target_kcal: 400, target_protein_g: 30, target_carbs_g: 50, target_fat_g: 10, user: user) }
  let(:meal_b) { plan.meals.create!(position: 2, name: "B", scheduled_time: Time.utc(2000, 1, 1, 12, 0), target_kcal: 600, target_protein_g: 45, target_carbs_g: 60, target_fat_g: 20, user: user) }

  describe ".yesterday" do
    it "returns the log dated yesterday" do
      log = DailyLog.create!(date: Date.yesterday, plan: plan, user: user)
      expect(DailyLog.yesterday(user: user)).to eq(log)
    end

    it "returns nil when no log exists for yesterday" do
      DailyLog.where(date: Date.yesterday).destroy_all
      expect(DailyLog.yesterday(user: user)).to be_nil
    end
  end

  describe "#can_copy_from?" do
    let(:today) { DailyLog.today(user: user) }

    it "is true when other shares the same plan" do
      yesterday = DailyLog.create!(date: Date.yesterday, plan: today.plan, user: user)
      expect(today.can_copy_from?(yesterday)).to be true
    end

    it "is false when other is nil" do
      expect(today.can_copy_from?(nil)).to be false
    end

    it "is false when other has a different plan" do
      other_plan
      yesterday = DailyLog.create!(date: Date.yesterday, plan: other_plan, user: user)
      expect(today.can_copy_from?(yesterday)).to be false
    end
  end

  describe "#has_uncopied_completions_from?" do
    let(:today) { DailyLog.today(user: user) }

    it "is true when other has more completions than self" do
      yesterday = DailyLog.create!(date: Date.yesterday, plan: today.plan, user: user)
      yesterday.meal_completions.create!(meal: meal_a, completed_at: 1.day.ago)
      expect(today.has_uncopied_completions_from?(yesterday)).to be true
    end

    it "is false when other has zero completions" do
      yesterday = DailyLog.create!(date: Date.yesterday, plan: today.plan, user: user)
      expect(today.has_uncopied_completions_from?(yesterday)).to be false
    end

    it "is false when self already has equal-or-more completions" do
      yesterday = DailyLog.create!(date: Date.yesterday, plan: today.plan, user: user)
      yesterday.meal_completions.create!(meal: meal_a, completed_at: 1.day.ago)
      today.meal_completions.create!(meal: meal_a, completed_at: Time.current)
      expect(today.has_uncopied_completions_from?(yesterday)).to be false
    end

    it "is false when authorization fails (different plan)" do
      other_plan
      yesterday = DailyLog.create!(date: Date.yesterday, plan: other_plan, user: user)
      yesterday.meal_completions.create!(meal: meal_a, completed_at: 1.day.ago)
      expect(today.has_uncopied_completions_from?(yesterday)).to be false
    end
  end

  describe "#habit_adherence_pct" do
    it "is 0% when a quantity habit's value is below target (all-or-nothing)" do
      habit = create(:habit, :quantity, user: user, target_value: 8)
      log = DailyLog.create!(date: Date.current, plan: plan, user: user)
      HabitEntry.set_value!(daily_log: log, habit: habit, value: 3)

      expect(log.habit_adherence_pct).to eq(0)
    end

    it "is 100% when a quantity habit's value meets target exactly" do
      habit = create(:habit, :quantity, user: user, target_value: 8)
      log = DailyLog.create!(date: Date.current, plan: plan, user: user)
      HabitEntry.set_value!(daily_log: log, habit: habit, value: 8)

      expect(log.habit_adherence_pct).to eq(100)
    end

    it "treats a nil target as done for any positive value (fallback)" do
      habit = create(:habit, :quantity, user: user, target_value: nil)
      log = DailyLog.create!(date: Date.current, plan: plan, user: user)
      HabitEntry.set_value!(daily_log: log, habit: habit, value: 2)

      expect(log.habit_adherence_pct).to eq(100)
    end

    it "excludes rating habits from both numerator and denominator" do
      binary_done = create(:habit, label: "A", position: 0, user: user)
      create(:habit, label: "B", position: 1, user: user) # binary, not done — no entry
      rating = create(:habit, :rating, label: "C", position: 2, user: user, rating_scale: 5)
      log = DailyLog.create!(date: Date.current, plan: plan, user: user)
      HabitEntry.set_value!(daily_log: log, habit: binary_done, value: 1)
      HabitEntry.set_value!(daily_log: log, habit: rating, value: 5)

      # 1 of 2 binary habits done = 50%. If the rating leaked into the
      # denominator this would be 33% (1/3); into the numerator too, 66% (2/3).
      expect(log.habit_adherence_pct).to eq(50)
    end
  end

  describe "#copy_completions_from" do
    let(:today) { DailyLog.today(user: user) }
    let(:yesterday) { DailyLog.create!(date: Date.yesterday, plan: today.plan) }

    it "returns the count actually inserted, skipping pre-existing meals" do
      yesterday.meal_completions.create!(meal: meal_a, completed_at: 1.day.ago)
      yesterday.meal_completions.create!(meal: meal_b, completed_at: 1.day.ago)
      today.meal_completions.create!(meal: meal_a, completed_at: 2.hours.ago)

      expect(today.copy_completions_from(yesterday)).to eq(1)
      expect(today.meal_completions.count).to eq(2)
    end

    it "returns 0 when nothing to copy" do
      expect(today.copy_completions_from(yesterday)).to eq(0)
    end

    it "rolls back the entire copy if any insert fails" do
      yesterday.meal_completions.create!(meal: meal_a, completed_at: 1.day.ago)
      yesterday.meal_completions.create!(meal: meal_b, completed_at: 1.day.ago)

      allow(today.meal_completions).to receive(:create!).and_call_original
      allow(today.meal_completions).to receive(:create!).with(hash_including(meal_id: meal_b.id))
                                                       .and_raise(ActiveRecord::RecordInvalid)

      expect { today.copy_completions_from(yesterday) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(today.meal_completions.count).to eq(0)
    end
  end
end
