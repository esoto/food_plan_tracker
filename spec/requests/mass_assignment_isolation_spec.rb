# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Mass-assignment isolation', type: :request do
  let(:owner) { create(:user, email_address: 'owner@example.com', password: 'password12345') }
  let(:other_user) { create(:user, email_address: 'other@example.com', password: 'password12345') }

  describe 'HTML PATCH isolation (inject user_id into body)' do
    before { sign_in_as owner }

    it 'PATCH /plans/:id ignores user_id in params' do
      plan = create(:plan, user: owner)
      patch plan_url(plan), params: { plan: { target_kcal: 2500, user_id: other_user.id } }
      expect(plan.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /goals/:id ignores user_id in params' do
      goal = create(:goal, user: owner)
      patch goal_url(goal), params: { goal: { target_value: 100, user_id: other_user.id } }
      expect(goal.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /meals/:id ignores user_id in params' do
      meal = create(:meal, user: owner)
      patch meal_url(meal), params: { meal: { name: 'NewName', user_id: other_user.id } }
      expect(meal.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /daily_logs/:id ignores user_id in params' do
      log = create(:daily_log, user: owner)
      patch daily_log_url(log), params: { daily_log: { notes: 'test', user_id: other_user.id } }
      expect(log.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /logged_foods/:id ignores user_id in params' do
      entry = create(:logged_food, user: owner)
      patch logged_food_url(entry), params: { logged_food: { quantity_grams: 150, user_id: other_user.id } }
      expect(entry.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /settings/supplements/:id ignores user_id in params' do
      supplement = create(:supplement, user: owner)
      patch settings_supplement_url(supplement), params: { supplement: { name: 'Updated', user_id: other_user.id } }
      expect(supplement.reload.user_id).to eq(owner.id)
    end
  end

  describe 'HTML POST isolation (inject user_id into body)' do
    before { sign_in_as owner }

    it 'POST /biomarker_entries ignores user_id in params' do
      goal = create(:goal, user: owner)
      expect {
        post biomarker_entries_url, params: {
          biomarker_entry: { goal_id: goal.id, value: 75.0, recorded_on: Date.current.to_s },
          user_id: other_user.id
        }
      }.to change(BiomarkerEntry, :count).by(1)
      entry = goal.biomarker_entries.order(:id).last
      expect(entry).to be_present
      expect(entry.user_id).to eq(owner.id)
    end

    it 'POST /settings/habits ignores user_id in params' do
      expect {
        post settings_habits_url, params: {
          habit: { label: 'NewHabitMA', user_id: other_user.id },
          user_id: other_user.id
        }
      }.to change(Habit, :count).by(1)
      habit = Habit.find_by!(label: 'NewHabitMA')
      expect(habit.user_id).to eq(owner.id)
    end

    it 'PATCH /settings/habits/:id ignores user_id in params' do
      habit = create(:habit, label: 'MineMA', position: 0, user: owner)
      patch settings_habit_url(habit), params: {
        habit: { label: 'UpdatedMA', user_id: other_user.id }
      }
      expect(habit.reload.user_id).to eq(owner.id)
      expect(habit.label).to eq('UpdatedMA')
    end

    it 'POST /settings/supplements ignores user_id in params' do
      post settings_supplements_url, params: {
        supplement: { name: 'NewSupp', dose: '1 cap', critical: false },
        user_id: other_user.id
      }
      expect([302, 303]).to include(response.status), "Expected redirect, got #{response.status}"
      supplement = Supplement.where(name: 'NewSupp').last
      expect(supplement).to be_present
      expect(supplement.user_id).to eq(owner.id)
    end
  end

  describe 'API V1 PATCH isolation (inject user_id into JSON body)' do
    before do
      # This describe exercises mass-assignment isolation on food endpoints
      # (meal_items, logged_foods), not the food-tracking flag — enable it
      # so the food-gate guard doesn't shadow the assertions under test.
      owner.update!(food_tracking_enabled: true)
      token = ApiToken.create!(user: owner, name: 'spec', token: 'test-token-123')
      @headers = { 'Authorization' => 'Bearer test-token-123', 'Content-Type' => 'application/json' }
    end

    it 'PATCH /api/v1/plans/:id ignores user_id in body' do
      plan = create(:plan, user: owner)
      patch "/api/v1/plans/#{plan.id}", params: { plan: { target_kcal: 2500, user_id: other_user.id } }.to_json, headers: @headers
      expect(response).not_to have_http_status(:forbidden)
      expect(plan.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /api/v1/goals/:id ignores user_id in body' do
      goal = create(:goal, user: owner)
      patch "/api/v1/goals/#{goal.id}", params: { goal: { target_value: 100, user_id: other_user.id } }.to_json, headers: @headers
      expect(goal.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /api/v1/meals/:id ignores user_id in body' do
      meal = create(:meal, user: owner)
      patch "/api/v1/meals/#{meal.id}", params: { meal: { name: 'Updated', user_id: other_user.id } }.to_json, headers: @headers
      expect(response).not_to have_http_status(:forbidden)
      expect(meal.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /api/v1/meal_items/:id ignores user_id in body' do
      meal = create(:meal, user: owner)
      item = create(:meal_item, meal: meal, user: owner)
      patch "/api/v1/meal_items/#{item.id}", params: { meal_item: { quantity_grams: 200, user_id: other_user.id } }.to_json, headers: @headers
      expect(response).not_to have_http_status(:forbidden)
      expect(item.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /api/v1/supplements/:id ignores user_id in body' do
      supplement = create(:supplement, user: owner)
      patch "/api/v1/supplements/#{supplement.id}", params: { supplement: { name: 'Updated', user_id: other_user.id } }.to_json, headers: @headers
      expect(supplement.reload.user_id).to eq(owner.id)
    end

    it 'PATCH /api/v1/habits/:id ignores user_id in body' do
      habit = create(:habit, user: owner)
      patch "/api/v1/habits/#{habit.id}", params: { habit: { label: 'Updated', user_id: other_user.id } }.to_json, headers: @headers
      expect(habit.reload.user_id).to eq(owner.id)
    end
  end

  describe 'API V1 POST isolation (inject user_id into JSON body)' do
    before do
      # This describe exercises mass-assignment isolation on food endpoints
      # (meal_items, logged_foods), not the food-tracking flag — enable it
      # so the food-gate guard doesn't shadow the assertions under test.
      owner.update!(food_tracking_enabled: true)
      token = ApiToken.create!(user: owner, name: 'spec', token: 'test-token-123')
      @headers = { 'Authorization' => 'Bearer test-token-123', 'Content-Type' => 'application/json' }
    end

    it 'POST /api/v1/meals/:id/items ignores user_id in body' do
      meal = create(:meal, user: owner)
      food = create(:food)
      post "/api/v1/meals/#{meal.id}/items", params: {
        meal_item: { food_id: food.id, quantity_grams: 100, user_id: other_user.id }
      }.to_json, headers: @headers
      item = meal.meal_items.order(:id).last
      expect(item).to be_present
      expect(item.user_id).to eq(owner.id)
    end

    it 'POST /api/v1/supplements ignores user_id in body' do
      post '/api/v1/supplements', params: {
        supplement: { name: 'NewSupp', dose: '1 cap', critical: false, user_id: other_user.id }
      }.to_json, headers: @headers
      supplement = Supplement.find_by!(name: 'NewSupp')
      expect(supplement.user_id).to eq(owner.id)
    end

    it 'POST /api/v1/habits ignores user_id in body' do
      post '/api/v1/habits', params: {
        habit: { label: 'NewHabit', description: 'test', user_id: other_user.id }
      }.to_json, headers: @headers
      habit = Habit.find_by!(label: 'NewHabit')
      expect(habit.user_id).to eq(owner.id)
    end

    it 'POST /api/v1/weight ignores user_id in body' do
      goal = Goal.find_or_create_by!(metric: Goal.metrics[:weight_kg], user: owner) do |g|
        g.display_name = "Weight"; g.unit = "kg"; g.direction = "down"
        g.starting_value = 80; g.target_value = 75
      end
      post '/api/v1/weight', params: {
        value: 78.5,
        date: Date.current.to_s,
        user_id: other_user.id
      }.to_json, headers: @headers
      entry = goal.biomarker_entries.order(:id).last
      expect(entry).to be_present
      expect(entry.user_id).to eq(owner.id)
    end

    it 'POST /api/v1/foods/:food_id/log ignores user_id in body' do
      create(:plan, slug: 'active', user: owner) # daily_log_for needs a plan to create today's log
      food = create(:food)
      expect {
        post "/api/v1/foods/#{food.id}/log", params: {
          quantity_grams: 150, user_id: other_user.id
        }.to_json, headers: @headers
      }.to change(LoggedFood, :count).by(1)
      entry = LoggedFood.order(:id).last
      expect(entry.user_id).to eq(owner.id)
    end
  end

  # Structurally immune endpoints — documented rather than tested, because no
  # attribute hash is ever permitted, so user_id injection has no path to the
  # model: meal_completions/supplement_completions (built from scoped meal/
  # supplement + daily_log lookups), habit_entries (find_or_initialize
  # off the scoped log), reminder_preferences (top-level reminder_type/key/
  # enabled only), push_subscriptions (for_user(Current.user) upsert), and the
  # HTML logged_foods create (food_id/daily_log_id + quantity only).
end
