class CreatePatientTreatments < ActiveRecord::Migration
  def self.up
    create_table :patient_treatments do |t|
      t.integer :patient_id
      t.integer :doctor_id
      t.integer :tooth_number
      t.string :name, :limit => 100
      t.float :price
      t.boolean :is_completed
      
      t.timestamps
    end
  end

  def self.down
    drop_table :patient_treatments
  end
end
