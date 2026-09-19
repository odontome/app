class AddOdontogramTreatmentPrices < ActiveRecord::Migration[8.1]
  def change
    add_column :treatments, :builtin_category, :string
    add_index :treatments, [:practice_id, :builtin_category], unique: true
    add_column :odontogram_entries, :price, :decimal, precision: 12, scale: 2
    add_column :odontogram_entries, :currency, :string
  end
end
