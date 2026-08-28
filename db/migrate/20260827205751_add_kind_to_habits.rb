class AddKindToHabits < ActiveRecord::Migration[8.1]
  def change
    add_column :habits, :kind, :integer, default: 0, null: false
    add_column :habits, :unit, :string
    add_column :habits, :target_value, :decimal, precision: 7, scale: 2
    add_column :habits, :rating_scale, :integer
  end
end
