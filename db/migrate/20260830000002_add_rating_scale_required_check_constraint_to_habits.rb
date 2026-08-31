class AddRatingScaleRequiredCheckConstraintToHabits < ActiveRecord::Migration[8.1]
  def change
    # Deferred hardening finding from PR #100: the model validation
    # (`validates :rating_scale, presence: true, if: :rating?`) can be
    # bypassed by upsert/raw SQL, which skip AR callbacks and validations.
    # This constraint makes the invariant hold at the DB layer too.
    # kind 3 = "rating" in Habit's kind enum (binary: 0, quantity: 1,
    # duration: 2, rating: 3).
    #
    # Existing dev/prod data must already satisfy this (every rating habit
    # has a rating_scale via the AR validation) — if it doesn't, this
    # migration fails loudly, which is the correct outcome.
    add_check_constraint :habits,
      "kind <> 3 OR rating_scale IS NOT NULL",
      name: "habits_rating_scale_required_for_rating"
  end
end
