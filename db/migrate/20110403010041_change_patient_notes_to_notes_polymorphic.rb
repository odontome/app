class ChangePatientNotesToNotesPolymorphic < ActiveRecord::Migration[5.0]
  def self.up
    change_table :patient_notes do |t|
      t.references :noteable, :polymorphic => true
      t.remove :patient_id
    end

    rename_table :patient_notes, :notes
  end

  def self.down
    change_table :patient_notes do |t|
      t.remove :noteable_id
      t.remove :noteable_type
      t.integer :patient_id
    end

    rename_table :notes, :patient_notes
  end
end
