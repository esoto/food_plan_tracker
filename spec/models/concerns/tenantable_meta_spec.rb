# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tenantable meta-tests', type: :model do
  # The canonical list of all Tenantable models, frozen at implementation.
  # If a new model is added with `include Tenantable`, it MUST be added here.
  # Drift-guard below will fail if live models don't match.
  TENANTABLE_MODELS = [
    ApiToken,
    BiomarkerEntry,
    Habit,
    DailyLog,
    Goal,
    LoggedFood,
    Meal,
    MealItem,
    Plan,
    PushSubscription,
    ReminderPreference,
    Supplement,
    SupplementSchedule
  ].freeze

  describe 'drift guard: enumerate all Tenantable models' do
    it 'detects when new Tenantable models are added without updating TENANTABLE_MODELS' do
      Rails.application.eager_load! unless Rails.application.config.eager_load

      live_models = ApplicationRecord.descendants.select do |model|
        model.included_modules.include?(Tenantable) && model.table_exists?
      end

      # Exclude ephemeral test models from the drift check
      live_models.reject! { |m| m.name&.start_with?('TenantableTest') }

      # Floor assertion: at least 13 models must be Tenantable
      expect(live_models.size).to be >= 13,
                                    "Expected at least 13 Tenantable models, found #{live_models.size}"

      missing_from_constant = live_models - TENANTABLE_MODELS
      missing_from_live = TENANTABLE_MODELS - live_models

      expect(missing_from_constant).to be_empty,
                                       "New Tenantable models not in TENANTABLE_MODELS: #{missing_from_constant.map(&:name).join(', ')}"
      expect(missing_from_live).to be_empty,
                                   "TENANTABLE_MODELS references models that don't include Tenantable: #{missing_from_live.map(&:name).join(', ')}"
    end
  end

  describe 'attr_readonly :user_id sweep' do
    TENANTABLE_MODELS.each do |model|
      describe model.name do
        it 'prevents user_id updates on existing records' do
          user = create(:user)
          other_user = create(:user)

          # Build the appropriate factory with user: owner
          record = case model.name
          when 'MealItem'
                     meal = create(:meal, user: user)
                     create(:meal_item, meal: meal, user: user)
          when 'LoggedFood'
                     log = create(:daily_log, user: user)
                     create(:logged_food, daily_log: log, user: user)
          when 'SupplementSchedule'
                     supplement = create(:supplement, user: user)
                     create(:supplement_schedule, supplement: supplement, user: user)
          else
                     create(model.name.underscore.to_sym, user: user)
          end

          # Attempt to change user_id — attr_readonly raises or silently drops the column
          begin
            record.update!(user_id: other_user.id)
          rescue ActiveRecord::ReadonlyAttributeError
            # attr_readonly is working correctly
          end

          # MUST reload — attr_readonly silently drops the column; in-memory may show attempted value
          record.reload

          expect(record.user_id).to eq(user.id),
                                   "#{model.name} user_id changed after update! — attr_readonly not working"
        end
      end
    end
  end

  describe 'for_user scoping' do
    TENANTABLE_MODELS.each do |model|
      next if model == MealItem  # Dedicated test below

      describe model.name do
        it 'excludes records owned by other users' do
          user_a = create(:user)
          user_b = create(:user)

          # Create a record for user_b
          case model.name
          when 'LoggedFood'
            log = create(:daily_log, user: user_b)
            create(:logged_food, daily_log: log, user: user_b)
          when 'SupplementSchedule'
            supplement = create(:supplement, user: user_b)
            create(:supplement_schedule, supplement: supplement, user: user_b)
          else
            create(model.name.underscore.to_sym, user: user_b)
          end

          # Query as user_a
          results = model.for_user(user_a)
          expect(results).to be_empty,
                             "#{model.name}.for_user(user_a) should exclude user_b's records"
        end
      end
    end

    describe 'MealItem cross-model sanity (dedicated example, out of loop)' do
      it 'scopes items to the meal owner, excluding strangers' do
        alice = create(:user)
        bob = create(:user)

        alice_meal = create(:meal, user: alice)
        alice_item = create(:meal_item, meal: alice_meal, user: alice)

        bob_meal = create(:meal, user: bob)
        _bob_item = create(:meal_item, meal: bob_meal, user: bob)

        expect(MealItem.for_user(alice)).to contain_exactly(alice_item),
                                             "MealItem.for_user(alice) should exclude bob's items"
      end
    end
  end

  describe 'for_user(nil) sweep' do
    TENANTABLE_MODELS.each do |model|
      describe model.name do
        it 'returns no records when called with nil' do
          user = create(:user)

          # Create a record
          case model.name
          when 'MealItem'
            meal = create(:meal, user: user)
            create(:meal_item, meal: meal, user: user)
          when 'LoggedFood'
            log = create(:daily_log, user: user)
            create(:logged_food, daily_log: log, user: user)
          when 'SupplementSchedule'
            supplement = create(:supplement, user: user)
            create(:supplement_schedule, supplement: supplement, user: user)
          else
            create(model.name.underscore.to_sym, user: user)
          end

          # Query with nil
          results = model.for_user(nil)
          expect(results).to be_empty,
                             "#{model.name}.for_user(nil) should return empty scope, not all records"
        end
      end
    end
  end

  describe 'assign_current_user sweep (top-level models via Current.session)' do
    # Exclude child models: MealItem, LoggedFood, SupplementSchedule (tested via parent derivation)
    top_level_models = [
      ApiToken, BiomarkerEntry, Habit, DailyLog,
      Goal, Meal, Plan, PushSubscription, ReminderPreference,
      Supplement
    ]

    top_level_models.each do |model|
      describe model.name do
        it 'derives user from Current.session on create' do
          user = create(:user)
          Current.session = Session.create!(user: user, user_agent: 'test', ip_address: '127.0.0.1')

          begin
            # Build with factory but don't persist
            attrs = case model.name
            when 'ApiToken'
                      { name: 'test-token' }
            when 'BiomarkerEntry'
                      goal = Goal.find_or_create_by!(metric: Goal.metrics[:weight_kg], user: user) do |g|
                        g.display_name = "Weight"; g.unit = "kg"; g.direction = "down"
                        g.starting_value = 80; g.target_value = 75
                      end
                      { goal_id: goal.id, value: 75.0, recorded_on: Date.current }
            when 'Habit'
                      { label: 'Test' }
            when 'DailyLog'
                      plan = Plan.find_or_create_by!(slug: 'test', user: user) do |p|
                        p.name = 'Test'; p.target_kcal = 2000
                        p.target_protein_g = 180; p.target_carbs_g = 180; p.target_fat_g = 70
                      end
                      { plan_id: plan.id, date: Date.current }
            when 'Goal'
                      { metric: Goal.metrics[:weight_kg], display_name: 'Weight', unit: 'kg', direction: 'down',
                        starting_value: 80, target_value: 75 }
            when 'Meal'
                      plan = Plan.find_or_create_by!(slug: 'test', user: user) do |p|
                        p.name = 'Test'; p.target_kcal = 2000
                        p.target_protein_g = 180; p.target_carbs_g = 180; p.target_fat_g = 70
                      end
                      { plan_id: plan.id, position: 1, name: 'Breakfast', scheduled_time: Time.utc(2000, 1, 1, 8, 0),
                        target_kcal: 600, target_protein_g: 50, target_carbs_g: 60, target_fat_g: 20 }
            when 'PushSubscription'
                      { endpoint: 'https://example.com/push', auth_key: 'key', p256dh_key: 'key' }
            when 'ReminderPreference'
                      { reminder_type: 'daily', key: 'breakfast' }
            when 'Supplement'
                      { name: 'Test' }
            end

            record = model.new(attrs)
            record.valid?

            expect(record.user).to eq(user),
                                   "#{model.name} should derive user from Current.session"
          ensure
            Current.reset
          end
        end
      end
    end
  end

  describe 'assign_current_user via parent association (child model derivation)' do
    it 'derives user from parent meal (MealItem)' do
      user = create(:user)
      Current.reset  # Ensure Current.user is nil

      meal = create(:meal, user: user)
      item = MealItem.new(meal: meal, food: create(:food), quantity_grams: 100, display_order: 1)
      item.valid?

      expect(item.user).to eq(user),
                           "MealItem should derive user from parent meal when Current.user is nil"
    end

    it 'derives user from parent daily_log (LoggedFood)' do
      user = create(:user)
      Current.reset  # Ensure Current.user is nil

      log = create(:daily_log, user: user)
      food = create(:food)
      entry = LoggedFood.new(daily_log: log, food: food, quantity_grams: 100, logged_at: Time.current)
      entry.valid?

      expect(entry.user).to eq(user),
                           "LoggedFood should derive user from parent daily_log when Current.user is nil"
    end

    it 'derives user from parent supplement (SupplementSchedule)' do
      user = create(:user)
      Current.reset  # Ensure Current.user is nil

      supplement = create(:supplement, user: user)
      schedule = SupplementSchedule.new(supplement: supplement, time_slot: 1, position: 1)
      schedule.valid?

      expect(schedule.user).to eq(user),
                              "SupplementSchedule should derive user from parent supplement when Current.user is nil"
    end
  end
end
