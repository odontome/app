class AddOdontogramPairedTooth < ActiveRecord::Migration[8.1]
  def change
    add_column :odontogram_entries, :paired_tooth, :integer
    add_index :odontogram_entries, [:patient_id, :paired_tooth]
  end
end
