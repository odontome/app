class AddOdontogramTreatmentStatus < ActiveRecord::Migration[8.1]
  def change
    add_column :odontogram_entries, :treatment_status, :string, default: 'existing', null: false
    add_column :odontogram_entries, :completed_at, :datetime
    add_check_constraint :odontogram_entries, "treatment_status IN ('existing', 'planned', 'completed')", name: 'odontogram_treatment_status'
  end
end
