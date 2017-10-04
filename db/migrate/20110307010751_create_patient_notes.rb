class CreatePatientNotes < ActiveRecord::Migration[5.0]
  def self.up
    create_table :patient_notes do |t|
      t.integer :patient_id
      t.string :notes, :limit => 500

      t.timestamps
    end
  end

  def self.down
    drop_table :patient_notes
  end
end
