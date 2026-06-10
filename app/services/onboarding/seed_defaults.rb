module Onboarding
  # Creates the minimum data a brand-new account needs to use the app:
  # the three day-type plans. Idempotent — find_or_initialize_by(slug:, user:)
  # mirrors db/seeds.rb, so re-running (or racing) is safe.
  #
  # Unlike seeds.rb (which reasserts targets on every run), this service
  # skips persisted plans so that user customizations are never overwritten.
  class SeedDefaults
    DEFAULT_PLANS = [
      { slug: Plan::EXERCISE_SLUG, name: "Exercise day", target_kcal: 2100,
        target_protein_g: 180, target_carbs_g: 215, target_fat_g: 75 },
      { slug: Plan::ACTIVE_SLUG, name: "Active day", target_kcal: 2075,
        target_protein_g: 180, target_carbs_g: 180, target_fat_g: 80 },
      { slug: Plan::REST_SLUG, name: "Rest day", target_kcal: 2050,
        target_protein_g: 180, target_carbs_g: 160, target_fat_g: 85 }
    ].freeze

    def self.call(user)
      DEFAULT_PLANS.each do |attrs|
        plan = Plan.find_or_initialize_by(slug: attrs[:slug], user: user)
        next if plan.persisted?

        plan.assign_attributes(attrs.except(:slug))
        plan.save!
      end
      user
    end
  end
end
