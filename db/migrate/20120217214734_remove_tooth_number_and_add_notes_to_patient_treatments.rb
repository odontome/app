class RemoveToothNumberAndAddNotesToPatientTreatments < ActiveRecord::Migration
  def self.up
  	change_table :patient_treatments do |t|
  	  t.remove :tooth_number
  	  t.string :notes, :limit => 500
  	end
  end

  def self.down
  	change_table :patient_treatments do |t|
  	  t.remove :notes
  	  t.integer :tooth_number
  	end
  end
end