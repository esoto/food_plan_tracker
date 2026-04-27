class AddUniqueIndexToMealItemsOnMealAndFood < ActiveRecord::Migration[8.1]
  # A meal with two rows for the same food was an unintended state — both
  # the controller and the MCP do first-match-wins lookups by food name on
  # update/remove, which would silently update only one row and orphan the
  # other. Enforce uniqueness at the DB and rely on `find_or_initialize_by`
  # at the create paths to upsert instead. Verified against production
  # (zero existing duplicates) before adding the constraint.
  def change
    add_index :meal_items, [ :meal_id, :food_id ],
              unique: true,
              name:   "index_meal_items_on_meal_and_food"
  end
end
