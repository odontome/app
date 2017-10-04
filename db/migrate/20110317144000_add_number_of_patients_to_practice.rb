class AddNumberOfPatientsToPractice < ActiveRecord::Migration[5.0]
  def self.up
    change_table :practices do |t|
      t.integer :number_of_patients
    end
  end

  def self.down
    remove_column :practices, :number_of_patients
  end
end
