class RemovePatientsFromPlans < ActiveRecord::Migration
  def self.up
    change_table :plans do |t|
      t.remove :number_of_patients
    end
  end

  def self.down
    change_table :plans do |t|
      t.integer :number_of_patients
    end
  end
end