class BackfillUserId < ActiveRecord::Migration[8.1]
  TABLES = %w[
    plans meals daily_logs supplements supplement_schedules goals
    biomarker_entries checklist_templates logged_foods push_subscriptions
    reminder_preferences notification_deliveries api_tokens meal_items
  ].freeze

  def up
    # Skip if there is nothing to backfill (keeps test / already-clean DBs tidy)
    has_nulls = TABLES.any? { |t| ActiveRecord::Base.connection.select_value("SELECT EXISTS (SELECT 1 FROM #{t} WHERE user_id IS NULL)") }
    return unless has_nulls

    email = "esoto074@gmail.com"
    user = User.find_by(email_address: email)

    unless user
      password = SecureRandom.hex(16)
      user = User.create!(email_address: email, password: password)
    end

    default_user_id = user.id

    # Parent tables — direct assignment
    [
      Plan, Goal, Supplement, ChecklistTemplate,
      ReminderPreference, ApiToken, PushSubscription, NotificationDelivery
    ].each do |model|
      model.where(user_id: nil).update_all(user_id: default_user_id)
    end

    # Child tables — derive user_id from parent association
    Meal.where(user_id: nil).joins(:plan).update_all("user_id = plans.user_id")
    DailyLog.where(user_id: nil).joins(:plan).update_all("user_id = plans.user_id")
    SupplementSchedule.where(user_id: nil).joins(:supplement).update_all("user_id = supplements.user_id")
    BiomarkerEntry.where(user_id: nil).joins(:goal).update_all("user_id = goals.user_id")
    LoggedFood.where(user_id: nil).joins(:daily_log).update_all("user_id = daily_logs.user_id")
    MealItem.where(user_id: nil).joins(:meal).update_all("user_id = meals.user_id")
  end

  def down
    # No-op: backfill cannot be undone safely
  end
end
