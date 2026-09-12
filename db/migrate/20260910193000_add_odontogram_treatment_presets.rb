class AddOdontogramTreatmentPresets < ActiveRecord::Migration[8.1]
  def change
    add_column :treatments, :odontogram_category, :string
    add_column :odontogram_entries, :treatment_snapshot, :jsonb, default: {}, null: false
  end
end
