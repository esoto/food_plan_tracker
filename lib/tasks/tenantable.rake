require "securerandom"

namespace :tenantable do
  desc "Create a default owner user if one does not exist"
  task create_default_owner: :environment do
    email = "esoto074@gmail.com"
    user = User.find_or_initialize_by(email_address: email)

    if user.persisted?
      puts "Default owner already exists: id=#{user.id}"
    else
      password = SecureRandom.hex(16)
      user.password = password
      user.save!
      puts "Created default owner: id=#{user.id}"
      puts "  Password (randomly generated): #{password}"
    end
  end

  desc "Backfill user_id on all tenantable tables using the default owner"
  task backfill_user_id: :environment do
    default_owner = User.find_by!(email_address: "esoto074@gmail.com")
    default_user_id = default_owner.id

    parent_tables = [
      Plan,
      Goal,
      Supplement,
      ChecklistTemplate,
      ReminderPreference,
      ApiToken,
      PushSubscription,
      NotificationDelivery
    ]

    parent_tables.each do |model|
      count = model.where(user_id: nil).update_all(user_id: default_user_id)
      puts "  Backfilled #{model.table_name}: #{count} rows updated"
    end

    child_updates = {
      "Meal"            => -> { Meal.where(user_id: nil).joins(:plan).update_all("user_id = plans.user_id") },
      "DailyLog"        => -> { DailyLog.where(user_id: nil).joins(:plan).update_all("user_id = plans.user_id") },
      "SupplementSchedule" => -> { SupplementSchedule.where(user_id: nil).joins(:supplement).update_all("user_id = supplements.user_id") },
      "BiomarkerEntry"  => -> { BiomarkerEntry.where(user_id: nil).joins(:goal).update_all("user_id = goals.user_id") },
      "LoggedFood"      => -> { LoggedFood.where(user_id: nil).joins(:daily_log).update_all("user_id = daily_logs.user_id") },
      "MealItem"        => -> { MealItem.where(user_id: nil).joins(:meal).update_all("user_id = meals.user_id") }
    }

    child_updates.each do |name, block|
      count = block.call
      puts "  Backfilled #{name.tableize}: #{count} rows updated"
    end

    # Verify zero NULL user_id rows remain across all tenantable tables
    all_tenantable_models = parent_tables + child_updates.keys.map(&:constantize)
    remaining = {}

    all_tenantable_models.each do |model|
      count = model.where(user_id: nil).count
      remaining[model.table_name] = count if count.positive?
    end

    if remaining.any?
      details = remaining.map { |table, count| "#{table}: #{count}" }.join(", ")
      abort "ERROR: NULL user_id rows remain after backfill: #{details}"
    end

    puts "Backfill complete. All tenantable tables verified — no NULL user_id rows remain."
  end
end
