class AddDiscardedAtToSupplements < ActiveRecord::Migration[8.1]
  def change
    add_column :supplements, :discarded_at, :datetime
    add_index :supplements, :discarded_at
  end
end
