class RemovePatientTreatments < ActiveRecord::Migration[5.0]
  def up
  	drop_table :patient_treatments
  end

  def down
  	create_table :patient_treatments do |t|
      t.integer :patient_id
      t.integer :doctor_id
      t.string :notes, :limit => 500
      t.string :name, :limit => 100
      t.float :price
      t.boolean :is_completed
      
      t.timestamps
    end
  end
end
